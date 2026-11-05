// Dart <-> Health Connect (Google Health) bridge + JSON disk cache.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import 'import_parser.dart';
import 'intervals_service.dart';

enum HcStatus { available, updateRequired, unavailable }

/// "Everything": 100 years back (Health Connect only returns what exists).
const int kAllDays = 36500;

class HealthService extends ChangeNotifier {
  HealthService._();
  static final instance = HealthService._();
  static const _ch = MethodChannel('healthstats/health');

  List<Workout> workouts = [];
  List<DayStat> days = [];
  bool loading = false;
  bool permitted = false;
  HcStatus status = HcStatus.unavailable;
  DateTime? lastSync;
  String? error;
  // Text + progress (0..1, null = unknown) shown by the loader
  String stage = '';
  double? progress;
  final Map<String, List<RoutePoint>> _routes = {};
  // ── Imported activities (GPX / FIT files) ──
  List<Map<String, dynamic>> _imports = [];
  final Map<String, List<RoutePoint>> _impRoutes = {};
  final Map<String, List<(DateTime, int)>> _impHr = {};
  bool importing = false;
  int get importCount => _imports.length;
  final Map<String, List<String>> _alt = {}; // merged duplicates: main id -> other ids
  final Set<String> _statsOk = {}; // sessions whose stats are already saved
  final Set<String> _hrGeneral = {};      // sessions whose heart rate comes from the phone's general heart-rate data
  final Map<String, int> _hrChecked = {}; // session id -> last time we looked for general heart rate (ms)
  bool hrIsGeneral(Workout w) => _hrGeneral.contains(w.id);
  Set<String> grantedPerms = {};
  bool get hasRoutePerm => grantedPerms.any((p) => p.endsWith('READ_EXERCISE_ROUTE'));
  /// Is a Health Connect permission granted? [name] = end of the permission, e.g. 'READ_POWER'.
  bool hasPerm(String name) => grantedPerms.any((p) => p.endsWith(name));
  /// Asks for everything again; if Android no longer shows its dialog (denied twice),
  /// opens Health Connect so the user can allow it there. Returns true when [name] is now granted.
  Future<bool> ensurePerm(String name) async {
    if (hasPerm(name)) return true;
    await requestPermissions();
    await refreshStatus(); // trust Health Connect, not only the dialog result
    if (!hasPerm(name)) { await openHealthConnect(); }
    return hasPerm(name);
  }
  String? routeError;
  bool get hasHistoryPerm => grantedPerms.any((p) => p.endsWith('READ_HEALTH_DATA_HISTORY'));

  // App icons (PNG) by package name
  final Map<String, Uint8List> appIcons = {};

  // Small GPS tracks for the map tab (saved on disk)
  final Map<String, List<LatLng>> tracks = {};
  final Set<String> _noTrack = {};
  bool trackBusy = false;
  double trackProgress = 0;

  Future<void> init() async {
    await _loadCache();
    loadAppInfo();
    await refreshStatus();
    if (permitted) sync();
  }

  Future<void> refreshStatus() async {
    try {
      final s = await _ch.invokeMethod<String>('status').timeout(const Duration(seconds: 10));
      status = switch (s) { 'available' => HcStatus.available, 'update_required' => HcStatus.updateRequired, _ => HcStatus.unavailable };
      if (status == HcStatus.available) {
        final g = (await _ch.invokeMethod<List>('granted').timeout(const Duration(seconds: 10)))?.cast<String>() ?? [];
        grantedPerms = g.toSet();
        permitted = g.any((p) => p.endsWith('READ_EXERCISE'));
      }
    } catch (e) { error = '$e'; }
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    try {
      final g = (await _ch.invokeMethod<List>('requestPermissions'))?.cast<String>() ?? [];
      grantedPerms = g.toSet();
      permitted = g.any((p) => p.endsWith('READ_EXERCISE'));
      notifyListeners();
      // Do NOT wait for the sync here: the permission screen must never stay blocked
      if (permitted) { sync(); }
    } catch (e) { error = '$e'; notifyListeners(); }
    return permitted;
  }

  Future<void> openHealthConnect() async { try { await _ch.invokeMethod('openSettings'); } catch (_) {} }

  Future<List> _list(String m, Map a, Duration t) async =>
      (await _ch.invokeMethod<List>(m, a).timeout(t)) ?? [];

  /// Sync: ALL available history (as far as Health Connect allows).
  /// Step 1 shows the session list at once, step 2 fills in the stats.
  Future<void> sync({int daysBack = kAllDays}) async {
    if (loading || !permitted) return;
    loading = true; error = null; progress = null;
    stage = _fr ? 'Lecture des activités…' : 'Reading activities…';
    notifyListeners();
    try {
      final end = DateTime.now().millisecondsSinceEpoch;
      final start = DateTime.now().subtract(Duration(days: daysBack)).millisecondsSinceEpoch;
      final a = {'start': start, 'end': end};

      // 1) quick list (no stats)
      final lite = await _list('sessions', {...a, 'lite': true}, const Duration(seconds: 45));
      final old = {for (final w in workouts) w.id: w};
      final liteWs = lite.map((e) => Workout.fromMap(Map.from(e as Map))).toList();
      final newIds = {for (final w in liteWs) w.id};
      // saved activities stay even if Health Connect does not return them any more
      workouts = [for (final w in liteWs) old[w.id] ?? w, for (final w in old.values) if (!newIds.contains(w.id) && !w.id.startsWith('imp_')) w]
        ..sort((x, y) => y.start.compareTo(x.start));
      _applyImports();
      stage = _fr ? 'Calcul des statistiques (${workouts.length} activités)…' : 'Computing stats (${workouts.length} activities)…';
      progress = 0.4;
      notifyListeners();

      // 2) stats, newest first, 25 sessions at a time (short calls, the screen updates after each one)
      final need = workouts.where((w) => !_statsOk.contains(w.id)).toList();
      var fails = 0;
      for (var i = 0; i < need.length && fails < 2; i += 25) {
        final g = need.skip(i).take(25).toList();
        try {
          final ws = await _list('sessions', {
            'start': g.last.start.millisecondsSinceEpoch - 1000,
            'end': g.first.end.millisecondsSinceEpoch + 1000}, const Duration(seconds: 60));
          final byId = {for (final w in workouts) w.id: w};
          for (final e in ws) { final w = Workout.fromMap(Map.from(e as Map)); byId[w.id] = w; _statsOk.add(w.id); _hrGeneral.remove(w.id); _hrChecked.remove(w.id); }
          workouts = byId.values.toList()..sort((x, y) => y.start.compareTo(x.start));
          _applyImports();
          fails = 0;
        } catch (e) {
          fails++;
          error = _fr ? 'Statistiques incomplètes : $e' : 'Incomplete stats: $e';
        }
        progress = 0.4 + 0.4 * ((i + 25) / need.length).clamp(0.0, 1.0).toDouble();
        stage = _fr ? 'Statistiques ${(i + 25).clamp(0, need.length)} / ${need.length}…' : 'Stats ${(i + 25).clamp(0, need.length)} / ${need.length}…';
        notifyListeners();
      }
      stage = _fr ? 'Pas, calories, distance…' : 'Steps, calories, distance…';
      progress = 0.8;
      notifyListeners();

      // 3) daily totals, recent first: last year, then each older year (stops after 5 empty years in a row)
      try {
        final byDay = {for (final d in days) d.day: d};
        var hi = DateTime.now(), empty = 0;
        for (var y = 0; y < 100 && empty < 5; y++) {
          final lo = DateTime(hi.year - 1, hi.month, hi.day);
          stage = _fr ? 'Historique ${lo.year}…' : 'History ${lo.year}…';
          notifyListeners();
          final ds = (await _list('daily', {'start': lo.millisecondsSinceEpoch, 'end': hi.millisecondsSinceEpoch},
              const Duration(minutes: 2))).map((e) => DayStat.fromMap(Map.from(e as Map))).toList();
          var any = false;
          for (final d in ds) { byDay[d.day] = d; if (d.steps > 0 || d.hrAvg > 0) any = true; }
          empty = any ? 0 : empty + 1;
          days = byDay.values.toList()..sort((x, y) => x.day.compareTo(y.day));
          notifyListeners(); // the screen already shows this period
          hi = lo;
        }
      } catch (_) {}

      lastSync = DateTime.now();
      _applyImports();
      await _saveCache();
      IntervalsService.credentials().then((c) { if (c != null) syncIntervals(days: 30); });
      _fillHeight();
      fillMissingHr();
      loadAppInfo();
      // small route previews for the activity list (newest first, in the background)
      loadTracks([for (final w in workouts) if (w.hasRoute) w].take(60).toList());
    } on PlatformException catch (e) { error = e.message ?? e.code; }
    on TimeoutException { error = _fr ? 'Health Connect ne répond pas. Réessayez.' : 'Health Connect is not answering. Try again.'; }
    catch (e) { error = '$e'; }
    finally {
      loading = false; progress = null; stage = '';
      notifyListeners();
    }
  }

  /// Reads name + icon of the source apps (only the ones not loaded yet).
  Future<void> loadAppInfo() async {
    final pkgs = {for (final w in workouts) if (w.source.isNotEmpty) w.source}.where((p) => !appIcons.containsKey(p) && !kAppLabels.containsKey(p)).toList();
    if (pkgs.isEmpty) return;
    try {
      final r = (await _ch.invokeMethod<List>('appInfo', {'pkgs': pkgs}).timeout(const Duration(seconds: 20))) ?? [];
      for (final e in r) {
        final m = e as Map;
        final pkg = m['pkg'] as String;
        if (m['label'] != null) kAppLabels[pkg] = m['label'] as String;
        if (m['icon'] != null) appIcons[pkg] = m['icon'] as Uint8List;
        if (m['label'] == null) kAppLabels[pkg] = '';
      }
      notifyListeners();
    } catch (_) {}
  }

  bool get _fr => localeNotifier.value == 'fr';

  /// Fill the height from Health Connect if the user did not set one.
  Future<void> _fillHeight() async {
    if (profileHeightNotifier.value > 0) return;
    try {
      final h = await _ch.invokeMethod<double>('height').timeout(const Duration(seconds: 10));
      if (h != null && h > 50) profileHeightNotifier.value = h.roundToDouble();
    } catch (_) {}
  }

  /// [ask]: if Health Connect wants a per-session consent, show its dialog.
  /// [maxPoints] > 0 = small route (map tab), not kept in memory.
  Future<List<RoutePoint>> route(Workout w, {bool ask = false, int maxPoints = 0}) async {
    final ids = [w.id, ...(_alt[w.id] ?? const <String>[])];
    for (final id in ids) {
      final imp = _impRoutes[id];
      if (imp != null) {
        if (maxPoints <= 0 || imp.length <= maxPoints) return imp;
        final step = (imp.length / maxPoints).ceil();
        return [for (var i = 0; i < imp.length; i += step) imp[i]];
      }
    }
    if (maxPoints == 0) { for (final id in ids) { if (_routes.containsKey(id)) return _routes[id]!; } }
    Object? lastErr;
    for (final id in ids) {
      if (id.startsWith('imp_')) continue;
      try {
        final r = (await _ch.invokeMethod<List>('route', {'id': id, 'ask': ask, 'max': maxPoints}).timeout(ask ? const Duration(minutes: 3) : const Duration(seconds: 40))) ?? [];
        final pts = r.map((e) {
          final l = (e as List).cast<num>();
          return RoutePoint(LatLng(l[0].toDouble(), l[1].toDouble()), l[2].toDouble(),
              DateTime.fromMillisecondsSinceEpoch(l[3].toInt()));
        }).toList();
        if (pts.length > 1) {
          routeError = null;
          if (maxPoints == 0) _routes[w.id] = pts;
          return pts;
        }
        lastErr = 'no_route';
      } catch (e) {
        lastErr = e;
        if ('$e'.contains('consent_denied')) break;
      }
    }
    final m = '$lastErr';
    final fr = localeNotifier.value == 'fr';
    routeError = m.contains('no_route')
        ? (fr ? 'Health Connect n’a aucun tracé GPS pour cette séance : l’app qui l’a enregistrée ne l’a pas envoyé.'
                : 'Health Connect has no GPS route for this session: the app that recorded it did not send one.')
        : m.contains('consent_denied')
            ? (fr ? 'L’accès au tracé a été refusé ou fermé. Appuie sur le bouton et choisis « Autoriser ».'
                    : 'Route access was refused or closed. Tap the button and choose “Allow”.')
            : m;
    return [];
  }

  /// Loads small tracks for the map (6 at a time, small routes), saves them on disk.
  Future<void> loadTracks(List<Workout> ws, {bool ask = false}) async {
    if (trackBusy) return;
    final todo = [for (final w in ws) if (w.hasRoute && !tracks.containsKey(w.id) && (ask || !_noTrack.contains(w.id))) w];
    if (todo.isEmpty) return;
    trackBusy = true; trackProgress = 0; notifyListeners();
    var done = 0;
    for (var i = 0; i < todo.length; i += ask ? 1 : 8) {
      // with consent dialogs: one by one
      final batch = todo.skip(i).take(ask ? 1 : 8).toList();
      await Future.wait(batch.map((w) async {
        final r = await route(w, ask: ask, maxPoints: 150);
        if (r.length > 1) {
          tracks[w.id] = [for (final p in r) p.pos];
        } else { _noTrack.add(w.id); }
      }));
      done += batch.length;
      if (done % 24 == 0) { _saveTracks(); }
      trackProgress = done / todo.length;
      notifyListeners();
    }
    trackBusy = false; trackProgress = 1;
    await _saveTracks();
    notifyListeners();
  }

  /// Heart-rate curve: [(time, bpm)].
  Future<List<(DateTime, int)>> heartRate(Workout w) async {
    final imp = _impHr[w.id];
    if (imp != null && w.id.startsWith('imp_')) return imp;
    final r = await _heartRateHc(w);
    if (r.isNotEmpty && _applyHr(w, r)) { notifyListeners(); _saveCache(); }
    return r.isEmpty && imp != null ? imp : r;
  }

  /// A session without heart-rate stats takes them from the heart-rate samples recorded by the phone / watch
  /// during the session (even when another app wrote them). Returns true when the session was updated.
  bool _applyHr(Workout w, List<(DateTime, int)> samples) {
    if (w.hrAvg > 0) return false;
    final v = [for (final e in samples) if (e.$2 >= 30 && e.$2 <= 230) e.$2];
    if (v.length < 3) return false;
    final i = workouts.indexWhere((x) => x.id == w.id);
    if (i < 0) return false;
    final avg = v.fold<int>(0, (a, b) => a + b) / v.length;
    workouts[i] = Workout.fromMap({...workouts[i].toMap(),
      'hrAvg': avg, 'hrMax': v.reduce((a, b) => a > b ? a : b).toDouble(), 'hrMin': v.reduce((a, b) => a < b ? a : b).toDouble()});
    _hrGeneral.add(w.id);
    return true;
  }

  /// Now and then: looks for heart rate in the sessions that have none. New sessions are retried for 3 days
  /// (the watch can sync late), older ones are checked once.
  Future<void> fillMissingHr({int max = 40}) async {
    if (!permitted || !hasPerm('READ_HEART_RATE')) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final todo = [for (final w in workouts)
      if (w.hrAvg <= 0 && !w.id.startsWith('imp_') && w.duration.inMinutes >= 3) w].where((w) {
        final last = _hrChecked[w.id];
        if (last == null) return true;
        final recent = DateTime.now().difference(w.end).inDays < 3;
        return recent && now - last > 3 * 3600 * 1000;
      }).take(max).toList();
    var changed = false;
    for (final w in todo) {
      final r = await _heartRateHc(w);
      _hrChecked[w.id] = now;
      if (_applyHr(w, r)) changed = true;
    }
    if (todo.isNotEmpty) { if (changed) notifyListeners(); await _saveCache(); }
  }

  Future<List<(DateTime, int)>> _heartRateHc(Workout w) async {
    try {
      final r = (await _ch.invokeMethod<List>('heartRate',
              {'start': w.start.millisecondsSinceEpoch, 'end': w.end.millisecondsSinceEpoch}).timeout(const Duration(seconds: 40))) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toInt()); }).toList();
    } catch (_) { return []; }
  }

  /// Recorded curve of a session: kind = speed (m/s) or power (W).
  Future<List<(DateTime, double)>> samples(String kind, Workout w) async {
    try {
      final r = (await _ch.invokeMethod<List>('samples', {'kind': kind,
              'start': w.start.millisecondsSinceEpoch, 'end': w.end.millisecondsSinceEpoch}).timeout(const Duration(seconds: 40))) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toDouble()); }).toList();
    } catch (_) { return []; }
  }

  // ── Vitals vault: sleep, resting HR, HRV, SpO2, weight are saved on the phone ──
  // Everything read once stays saved. After that only the newest days are asked
  // again (at most every 6 hours), and a failed read never erases saved data.
  final Map<String, List> _vault = {};
  final Map<String, int> _vaultAt = {};
  Future<void>? _vaultReady;
  Future<void> _readVault() async {
    for (final name in ['hs_vitals.json', 'hs_vitals.json.bak']) {
      try {
        final f = await _f(name);
        if (!await f.exists()) continue;
        final j = jsonDecode(await f.readAsString()) as Map;
        (j['rows'] as Map).forEach((k, v) => _vault[k as String] = List.from(v as List));
        (j['at'] as Map).forEach((k, v) => _vaultAt[k as String] = (v as num).toInt());
        return;
      } catch (_) {}
    }
  }
  Future<void> _saveVault() => _writeSafe('hs_vitals.json', jsonEncode({'rows': _vault, 'at': _vaultAt}));

  /// Writes a file without ever leaving it half written (temp file, then rename; old copy kept as .bak).
  Future<void> _writeSafe(String name, String data) async {
    try {
      final f = await _f(name), tmp = await _f('$name.tmp'), bak = await _f('$name.bak');
      await tmp.writeAsString(data, flush: true);
      if (await f.exists()) { try { await f.copy(bak.path); } catch (_) {} }
      await tmp.rename(f.path);
    } catch (_) {}
  }

  int _rowMs(String key, dynamic e) => key == 'sleep' ? ((e as Map)['end'] as num).toInt() : ((e as List)[0] as num).toInt();
  String _rowId(String key, dynamic e) => key == 'sleep' ? '${(e as Map)['start']}-${e['end']}' : '${(e as List)[0]}';

  Future<List> _vaultRows(String key, String method, Map<String, dynamic> args) async {
    await (_vaultReady ??= _readVault());
    final now = DateTime.now().millisecondsSinceEpoch;
    final have = _vault[key] ?? [];
    if (_vault.containsKey(key) && now - (_vaultAt[key] ?? 0) < 6 * 3600000) return have;
    final since = have.isEmpty
        ? DateTime.now().subtract(const Duration(days: kAllDays)).millisecondsSinceEpoch
        : _rowMs(key, have.last) - 3 * 86400000;
    try {
      final r = (await _ch.invokeMethod<List>(method, {...args, 'start': since, 'end': now}).timeout(const Duration(seconds: 90))) ?? [];
      if (r.isEmpty && have.isEmpty) return have;
      final map = {for (final e in have) _rowId(key, e): e};
      for (final e in r) {
        map[_rowId(key, e)] = key == 'sleep' ? Map<String, dynamic>.from((e as Map).map((k, v) => MapEntry(k as String, v)))
            : [for (final x in (e as List)) (x as num)];
      }
      final all = map.values.toList()..sort((a, b) => _rowMs(key, a).compareTo(_rowMs(key, b)));
      _vault[key] = all; _vaultAt[key] = now;
      await _saveVault();
      return all;
    } catch (_) { return have; } // keep what is already saved
  }

  /// Daily average of a vital sign (whole history, saved on the phone).
  Future<List<(DateTime, double)>> metric(String kind, {int days = kAllDays}) async {
    final r = await _vaultRows('m_$kind', 'metric', {'kind': kind});
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final per = <DateTime, List<double>>{};
    for (final e in r) {
      final l = (e as List).cast<num>();
      if (l[0] < from) continue;
      final t = DateTime.fromMillisecondsSinceEpoch(l[0].toInt());
      (per[DateTime(t.year, t.month, t.day)] ??= []).add(l[1].toDouble());
    }
    return per.entries.map((e) => (e.key, e.value.reduce((a, b) => a + b) / e.value.length)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// All sleep sessions (with real stages when the source gives them), saved on the phone.
  Future<List<Map>> sleepRaw({int days = kAllDays}) async {
    final r = await _vaultRows('sleep', 'sleep', {});
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return [for (final e in r) if (_rowMs('sleep', e) >= from) Map.from(e as Map)];
  }

  /// Hours slept per night (whole history), by wake-up day.
  Future<List<(DateTime, double)>> sleepNights({int days = kAllDays}) async {
    final per = <DateTime, double>{};
    for (final m in await sleepRaw(days: days)) {
      final a = DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()), b = DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt());
      final day = DateTime(b.year, b.month, b.day);
      per[day] = (per[day] ?? 0) + b.difference(a).inMinutes / 60;
    }
    return per.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// Last night (sessions grouped): bed time, wake time, minutes asleep.
  Future<({DateTime start, DateTime end, int minutes})?> lastSleep() async {
    final r = await sleepRaw(days: 4);
    final ss = [for (final m in r) (DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()), DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt()))];
    if (ss.isEmpty) return null;
    ss.sort((a, b) => b.$2.compareTo(a.$2));
    final end = ss.first.$2;
    final g = ss.where((x) => end.difference(x.$2).inHours < 14).toList();
    final st = g.map((x) => x.$1).reduce((a, b) => a.isBefore(b) ? a : b);
    return (start: st, end: end, minutes: g.fold<int>(0, (a, x) => a + x.$2.difference(x.$1).inMinutes));
  }

  Future<List<(DateTime, double)>> weights({int days = kAllDays}) async {
    final r = await _vaultRows('weight', 'weight', {});
    final from = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return [for (final e in r) if ((e as List)[0] >= from) (DateTime.fromMillisecondsSinceEpoch((e[0] as num).toInt()), (e[1] as num).toDouble())];
  }

  // ── Import GPX / FIT ──
  /// Puts imported activities into [workouts]: a file that matches a session (start within 10 min)
  /// gives that session its route / heart rate; otherwise it becomes a new activity.
  /// Returns the ids of the imports that matched an existing session.
  Set<String> _applyImports() {
    final matched = <String>{};
    _impRoutes.clear(); _impHr.clear();
    final base = _dedupe(workouts.where((w) => !w.id.startsWith('imp_')).toList());
    if (_imports.isEmpty) { workouts = base..sort((x, y) => y.start.compareTo(x.start)); return matched; }
    final out = base;
    for (final a in _imports) {
      final s = DateTime.fromMillisecondsSinceEpoch((a['start'] as num).toInt());
      final route = [for (final p in (a['route'] as List)) RoutePoint(LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          (p[2] as num).toDouble(), DateTime.fromMillisecondsSinceEpoch((p[3] as num).toInt()))];
      final hr = [for (final p in (a['hr'] as List)) (DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toInt())];
      final i = out.indexWhere((w) => w.start.difference(s).inMinutes.abs() <= 10);
      final id = i >= 0 ? out[i].id : a['id'] as String;
      if (route.length > 1) _impRoutes[id] = route;
      if (hr.isNotEmpty) _impHr[id] = hr;
      _statsOk.add(id);
      final dist = (a['distanceM'] as num).toDouble(), kcal = (a['kcal'] as num).toDouble();
      if (i >= 0) {
        matched.add(a['id'] as String);
        final w = out[i];
        if ((route.length > 1 && !w.hasRoute) || (w.distanceM <= 0 && dist > 0) || (w.hrAvg <= 0 && hr.isNotEmpty)) {
          out[i] = Workout.fromMap({...w.toMap(),
            if (route.length > 1) 'hasRoute': true,
            if (w.distanceM <= 0 && dist > 0) 'distanceM': dist,
            if (w.hrAvg <= 0 && hr.isNotEmpty) ...{'hrAvg': a['hrAvg'], 'hrMax': a['hrMax'], 'hrMin': a['hrMin']}});
        }
      } else {
        out.add(Workout.fromMap({
          'id': id, 'type': a['type'], 'title': a['title'] ?? '', 'source': a['source'] == 'intervals' ? 'intervals' : 'import',
          'notes': a['guessed'] == true ? (_fr ? 'Sport deviné d’après la vitesse' : 'Sport guessed from the speed') : '',
          'start': a['start'], 'end': a['end'], 'hasRoute': route.length > 1,
          'distanceM': dist, 'activeKcal': kcal, 'totalKcal': kcal, 'steps': 0,
          'hrAvg': a['hrAvg'], 'hrMax': a['hrMax'], 'hrMin': a['hrMin'], 'segments': const []}));
      }
    }
    workouts = out..sort((x, y) => y.start.compareTo(x.start));
    return matched;
  }

  // ── Merge duplicates (same activity written by several apps) ──
  // Lower rank = closer to the original app. Origin app first, then Google Fit, Strava, Intervals, files.
  int _rank(String s) {
    if (s == 'com.strava') return 3;
    if (s == 'intervals') return 4;
    if (s == 'import') return 5;
    if (s.isEmpty || s == 'com.google.android.apps.fitness' || s == 'com.google.android.apps.healthdata') return 2;
    return 0;
  }
  int _family(int t) => (t == 56 || t == 57) ? 1 : (t == 79 || t == 37) ? 2 : (t == 8 || t == 9) ? 3 : (t == 74 || t == 73) ? 4 : t;
  bool _sameSport(Workout a, Workout b) => a.type == 0 || b.type == 0 || _family(a.type) == _family(b.type);
  int _score(Workout w) => (w.hasRoute ? 4 : 0) + (w.distanceM > 0 ? 2 : 0) + (w.hrAvg > 0 ? 2 : 0) + (w.kcal > 0 ? 1 : 0);

  /// Groups sessions that start within 10 min with the same sport, keeps the best source and fills the gaps from the others.
  List<Workout> _dedupe(List<Workout> list) {
    _alt.clear();
    final sorted = [...list]..sort((a, b) => a.start.compareTo(b.start));
    final groups = <List<Workout>>[];
    for (final w in sorted) {
      List<Workout>? g;
      for (var i = groups.length - 1; i >= 0 && i >= groups.length - 6; i--) {
        if (groups[i].any((x) => x.start.difference(w.start).inMinutes.abs() <= 10 && _sameSport(x, w))) { g = groups[i]; break; }
      }
      if (g == null) { groups.add([w]); } else { g.add(w); }
    }
    return [for (final g in groups) g.length == 1 ? g.first : _mergeGroup(g)];
  }

  Workout _mergeGroup(List<Workout> g) {
    g.sort((a, b) { final r = _rank(a.source).compareTo(_rank(b.source)); return r != 0 ? r : _score(b).compareTo(_score(a)); });
    final p = g.first;
    double pick(double Function(Workout) f) { for (final w in g) { final v = f(w); if (v > 0) return v; } return 0; }
    final steps = g.map((w) => w.steps).firstWhere((s) => s > 0, orElse: () => 0);
    _alt[p.id] = [for (final w in g.skip(1)) w.id];
    return Workout(
      id: p.id, type: p.type != 0 ? p.type : g.firstWhere((w) => w.type != 0, orElse: () => p).type,
      title: g.map((w) => w.title).firstWhere((t) => t.isNotEmpty, orElse: () => ''),
      notes: g.map((w) => w.notes).firstWhere((t) => t.isNotEmpty, orElse: () => ''),
      source: p.source, start: p.start, end: p.end, hasRoute: g.any((w) => w.hasRoute),
      distanceM: pick((w) => w.distanceM), activeKcal: pick((w) => w.activeKcal), totalKcal: pick((w) => w.totalKcal),
      steps: steps, hrAvg: pick((w) => w.hrAvg), hrMax: pick((w) => w.hrMax), hrMin: pick((w) => w.hrMin),
      segments: g.map((w) => w.segments).firstWhere((s) => s.isNotEmpty, orElse: () => const []));
  }

  bool isNoTrack(String id) => _noTrack.contains(id);

  Future<void> _saveImports() async {
    try { await (await _f('hs_imports.json')).writeAsString(jsonEncode(_imports)); } catch (_) {}
  }

  /// Reads the chosen files (gpx, fit, .gz, Strava .zip) and adds them. Counts: new / matched with a session / unreadable.
  Future<({int added, int matched, int already, int failed})> importFiles(List<String> paths) async {
    importing = true; notifyListeners();
    try {
      final r = await parseImportFiles(paths);
      final x = await _addActs(r.acts);
      final added = x.$1, already = x.$3;
      final m = x.$2;
      loadTracks(workouts.where((w) => w.hasRoute).take(60).toList());
      return (added: added, matched: m, already: already, failed: r.errors.length);
    } finally { importing = false; notifyListeners(); }
  }

  // A start is "known" when an import within 10 min already has a route (no need to read it again).
  bool _knownStart(int ms) => _imports.any((a) => ((a['start'] as num).toInt() - ms).abs() <= 600000 && (a['route'] as List).length > 1);

  /// Fills the empty parts of [ex] from [nw] (same activity, other source). Returns true if something changed.
  bool _mergeImport(Map<String, dynamic> ex, Map<String, dynamic> nw) {
    var ch = false;
    if ((ex['route'] as List).length < 2 && (nw['route'] as List).length > 1) { ex['route'] = nw['route']; ch = true; }
    if ((ex['hr'] as List).isEmpty && (nw['hr'] as List).isNotEmpty) {
      ex['hr'] = nw['hr']; ex['hrAvg'] = nw['hrAvg']; ex['hrMax'] = nw['hrMax']; ex['hrMin'] = nw['hrMin']; ch = true;
    }
    for (final k in ['distanceM', 'kcal']) {
      if (((ex[k] as num?) ?? 0) <= 0 && ((nw[k] as num?) ?? 0) > 0) { ex[k] = nw[k]; ch = true; }
    }
    if ('${ex['title'] ?? ''}'.isEmpty && '${nw['title'] ?? ''}'.isNotEmpty) { ex['title'] = nw['title']; ch = true; }
    return ch;
  }

  /// Adds parsed activities (skipping ones whose start is within 2 min of an existing import).
  /// Returns (added, matched with an existing session, already known).
  Future<(int, int, int)> _addActs(List<Map<String, dynamic>> acts) async {
    var added = 0, already = 0;
    final fresh = <String>{};
    for (final a in acts) {
      final ms = (a['start'] as num).toInt();
      final ei = _imports.indexWhere((x) => ((x['start'] as num).toInt() - ms).abs() <= 600000);
      if (ei >= 0) { _mergeImport(_imports[ei], a); already++; continue; }
      final id = 'imp_${a['start']}';
      a['id'] = id; _imports.add(a); fresh.add(id); added++;
    }
    final m = _applyImports();
    await _saveImports();
    await _saveCache();
    return (added, m.where(fresh.contains).length, already);
  }

  // ── Intervals.icu ──
  String intervalsStage = '';
  double intervalsProgress = 0;
  bool intervalsBusy = false;
  String? intervalsError;
  ({int added, int matched, int strava, int known, int total})? intervalsResult;

  /// Reads activities, GPS routes and heart rate from Intervals.icu (free personal API key).
  Future<bool> syncIntervals({int days = 365}) async {
    final c = await IntervalsService.credentials();
    if (c == null || intervalsBusy) return false;
    intervalsBusy = true; intervalsError = null; intervalsResult = null; intervalsStage = _fr ? 'Connexion…' : 'Connecting…'; intervalsProgress = 0;
    notifyListeners();
    try {
      final r = await IntervalsService.fetch(key: c.$1, athlete: c.$2, days: days, fr: _fr, isKnown: _knownStart,
          onStage: (st, p) { intervalsStage = st; intervalsProgress = p; notifyListeners(); });
      if (r.error != null) { intervalsError = r.error; return false; }
      final x = await _addActs(r.acts);
      intervalsResult = (added: x.$1, matched: x.$2, strava: r.stravaSkipped, known: r.known, total: r.total);
      await IntervalsService.markSynced();
      loadTracks(workouts.where((w) => w.hasRoute).take(60).toList());
      return true;
    } catch (e) {
      intervalsError = '$e'; return false;
    } finally { intervalsBusy = false; notifyListeners(); }
  }

  Future<void> clearImports() async {
    _imports = []; _applyImports();
    try { await (await _f('hs_imports.json')).delete(); } catch (_) {}
    await _saveCache();
    notifyListeners();
  }

  // ── Disk cache ──
  Future<File> _f(String n) async => File('${(await getApplicationSupportDirectory()).path}/$n');
  Future<void> _saveCache() async {
    try {
      await _writeSafe('hs_cache.json', jsonEncode({
        'sync': lastSync?.millisecondsSinceEpoch,
        'si': _statsOk.toList(), 'hg': _hrGeneral.toList(), 'hc': _hrChecked, 'w': workouts.map((w) => w.toMap()).toList(), 'd': days.map((d) => d.toMap()).toList()}));
    } catch (_) {}
  }
  Future<void> _saveTracks() async {
    try {
      await (await _f('hs_tracks.json')).writeAsString(jsonEncode({
        for (final e in tracks.entries) e.key: [for (final p in e.value) [p.latitude, p.longitude]]}));
    } catch (_) {}
  }
  Future<void> _loadCache() async {
    for (final cname in ['hs_cache.json', 'hs_cache.json.bak']) {
      if (workouts.isNotEmpty) break;
      try {
      final f = await _f(cname);
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map;
        workouts = (j['w'] as List).map((e) => Workout.fromMap(e as Map)).toList();
        days = (j['d'] as List).map((e) => DayStat.fromMap(e as Map)).toList();
        _statsOk.addAll(j['si'] != null ? (j['si'] as List).cast<String>()
            : [for (final w in workouts) if (w.distanceM > 0 || w.hrAvg > 0 || w.kcal > 0 || w.steps > 0) w.id]);
        if (j['hg'] != null) _hrGeneral.addAll((j['hg'] as List).cast<String>());
        if (j['hc'] != null) (j['hc'] as Map).forEach((k, v) => _hrChecked[k as String] = (v as num).toInt());
        if (j['sync'] != null) lastSync = DateTime.fromMillisecondsSinceEpoch(j['sync'] as int);
      }
      } catch (_) {}
    }
    try {
      final f = await _f('hs_imports.json');
      if (await f.exists()) {
        _imports = [for (final e in jsonDecode(await f.readAsString()) as List) Map<String, dynamic>.from(e as Map)];
        _applyImports();
      }
    } catch (_) {}
    try {
      final f = await _f('hs_tracks.json');
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map;
        for (final e in j.entries) {
          tracks[e.key as String] = [for (final p in (e.value as List)) LatLng(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())];
        }
      }
    } catch (_) {}
  }

  /// Size of the local cache in bytes (shown before the user clears it).
  Future<int> cacheSize() async {
    var n = 0;
    for (final name in ['hs_cache.json', 'hs_tracks.json', 'hs_vitals.json']) {
      try { final f = await _f(name); if (await f.exists()) n += await f.length(); } catch (_) {}
    }
    return n;
  }

  /// Sizes in bytes of the two cache files.
  Future<(int, int)> cacheSizes() async {
    Future<int> sz(String n) async { try { final f = await _f(n); return await f.exists() ? await f.length() : 0; } catch (_) { return 0; } }
    return (await sz('hs_cache.json'), await sz('hs_tracks.json'));
  }

  Future<void> clearTracks() async {
    tracks.clear(); _noTrack.clear();
    try { await (await _f('hs_tracks.json')).delete(); } catch (_) {}
    notifyListeners();
  }

  Future<void> clearActivities() async {
    workouts = []; days = []; _routes.clear(); _statsOk.clear(); _hrGeneral.clear(); _hrChecked.clear(); lastSync = null;
    try { await (await _f('hs_cache.json')).delete(); } catch (_) {}
    notifyListeners();
  }

  /// Only call this after the user confirmed (see confirmClearCache).
  Future<void> clearCache() async {
    workouts = []; days = []; _routes.clear(); _statsOk.clear(); _hrGeneral.clear(); _hrChecked.clear(); tracks.clear(); _noTrack.clear(); lastSync = null;
    _vault.clear(); _vaultAt.clear();
    for (final name in ['hs_cache.json', 'hs_cache.json.bak', 'hs_tracks.json', 'hs_vitals.json', 'hs_vitals.json.bak']) {
      try { await (await _f(name)).delete(); } catch (_) {}
    }
    notifyListeners();
  }

  // ── Handy aggregations ──
  List<Workout> between(DateTime a, DateTime b) =>
      workouts.where((w) => !w.start.isBefore(a) && w.start.isBefore(b)).toList();
  Workout? get last => workouts.isEmpty ? null : workouts.first;
  Workout? lastOf(bool Function(Workout) f) { for (final w in workouts) { if (f(w)) return w; } return null; }
  DayStat? dayStat(DateTime d) {
    for (final s in days) { if (s.day.year == d.year && s.day.month == d.month && s.day.day == d.day) return s; }
    return null;
  }
}
