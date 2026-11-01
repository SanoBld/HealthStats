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

enum HcStatus { available, updateRequired, unavailable }

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
  Set<String> grantedPerms = {};
  bool get hasRoutePerm => grantedPerms.any((p) => p.endsWith('READ_EXERCISE_ROUTE'));
  bool get hasHistoryPerm => grantedPerms.any((p) => p.endsWith('READ_HEALTH_DATA_HISTORY'));

  // Small GPS tracks for the map tab (saved on disk)
  final Map<String, List<LatLng>> tracks = {};
  final Set<String> _noTrack = {};
  bool trackBusy = false;
  double trackProgress = 0;

  Future<void> init() async {
    await _loadCache();
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
  Future<void> sync({int daysBack = 3650}) async {
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
      workouts = [for (final w in liteWs) old[w.id] ?? w]..sort((x, y) => y.start.compareTo(x.start));
      stage = _fr ? 'Calcul des statistiques (${workouts.length} activités)…' : 'Computing stats (${workouts.length} activities)…';
      progress = 0.4;
      notifyListeners();

      // 2) full stats (parallel on the Kotlin side). Keep the list if this fails.
      try {
        final ws = await _list('sessions', a, const Duration(minutes: 3));
        workouts = ws.map((e) => Workout.fromMap(Map.from(e as Map))).toList()
          ..sort((x, y) => y.start.compareTo(x.start));
      } catch (e) {
        error = _fr ? 'Statistiques incomplètes : $e' : 'Incomplete stats: $e';
      }
      stage = _fr ? 'Pas, calories, distance…' : 'Steps, calories, distance…';
      progress = 0.8;
      notifyListeners();

      // 3) daily totals (optional)
      try {
        final ds = await _list('daily', {'start': DateTime.now().subtract(const Duration(days: 730)).millisecondsSinceEpoch, 'end': end},
            const Duration(minutes: 2));
        days = ds.map((e) => DayStat.fromMap(Map.from(e as Map))).toList()
          ..sort((x, y) => x.day.compareTo(y.day));
      } catch (_) {}

      lastSync = DateTime.now();
      await _saveCache();
      _fillHeight();
    } on PlatformException catch (e) { error = e.message ?? e.code; }
    on TimeoutException { error = _fr ? 'Health Connect ne répond pas. Réessayez.' : 'Health Connect is not answering. Try again.'; }
    catch (e) { error = '$e'; }
    finally {
      loading = false; progress = null; stage = '';
      notifyListeners();
    }
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
    if (maxPoints == 0 && _routes.containsKey(w.id)) return _routes[w.id]!;
    try {
      final r = (await _ch.invokeMethod<List>('route', {'id': w.id, 'ask': ask, 'max': maxPoints}).timeout(const Duration(seconds: 40))) ?? [];
      final pts = r.map((e) {
        final l = (e as List).cast<num>();
        return RoutePoint(LatLng(l[0].toDouble(), l[1].toDouble()), l[2].toDouble(),
            DateTime.fromMillisecondsSinceEpoch(l[3].toInt()));
      }).toList();
      if (pts.isNotEmpty && maxPoints == 0) _routes[w.id] = pts;
      return pts;
    } catch (_) { return []; }
  }

  /// Loads small tracks for the map (6 at a time, small routes), saves them on disk.
  Future<void> loadTracks(List<Workout> ws, {bool ask = false}) async {
    if (trackBusy) return;
    final todo = [for (final w in ws) if (w.hasRoute && !tracks.containsKey(w.id) && (ask || !_noTrack.contains(w.id))) w];
    if (todo.isEmpty) return;
    trackBusy = true; trackProgress = 0; notifyListeners();
    var done = 0;
    for (var i = 0; i < todo.length; i += 6) {
      final batch = todo.skip(i).take(6).toList();
      await Future.wait(batch.map((w) async {
        final r = await route(w, ask: ask, maxPoints: 150);
        if (r.length > 1) {
          tracks[w.id] = [for (final p in r) p.pos];
        } else { _noTrack.add(w.id); }
      }));
      done += batch.length;
      trackProgress = done / todo.length;
      notifyListeners();
    }
    trackBusy = false; trackProgress = 1;
    await _saveTracks();
    notifyListeners();
  }

  /// Heart-rate curve: [(time, bpm)].
  Future<List<(DateTime, int)>> heartRate(Workout w) async {
    try {
      final r = (await _ch.invokeMethod<List>('heartRate',
              {'start': w.start.millisecondsSinceEpoch, 'end': w.end.millisecondsSinceEpoch}).timeout(const Duration(seconds: 40))) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toInt()); }).toList();
    } catch (_) { return []; }
  }

  Future<List<(DateTime, double)>> weights() async {
    try {
      final r = (await _ch.invokeMethod<List>('weight', {
            'start': DateTime.now().subtract(const Duration(days: 730)).millisecondsSinceEpoch,
            'end': DateTime.now().millisecondsSinceEpoch}).timeout(const Duration(seconds: 30))) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toDouble()); }).toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
    } catch (_) { return []; }
  }

  // ── Disk cache ──
  Future<File> _f(String n) async => File('${(await getApplicationSupportDirectory()).path}/$n');
  Future<void> _saveCache() async {
    try {
      await (await _f('hs_cache.json')).writeAsString(jsonEncode({
        'sync': lastSync?.millisecondsSinceEpoch,
        'w': workouts.map((w) => w.toMap()).toList(), 'd': days.map((d) => d.toMap()).toList()}));
    } catch (_) {}
  }
  Future<void> _saveTracks() async {
    try {
      await (await _f('hs_tracks.json')).writeAsString(jsonEncode({
        for (final e in tracks.entries) e.key: [for (final p in e.value) [p.latitude, p.longitude]]}));
    } catch (_) {}
  }
  Future<void> _loadCache() async {
    try {
      final f = await _f('hs_cache.json');
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map;
        workouts = (j['w'] as List).map((e) => Workout.fromMap(e as Map)).toList();
        days = (j['d'] as List).map((e) => DayStat.fromMap(e as Map)).toList();
        if (j['sync'] != null) lastSync = DateTime.fromMillisecondsSinceEpoch(j['sync'] as int);
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
    for (final name in ['hs_cache.json', 'hs_tracks.json']) {
      try { final f = await _f(name); if (await f.exists()) n += await f.length(); } catch (_) {}
    }
    return n;
  }

  /// Only call this after the user confirmed (see confirmClearCache).
  Future<void> clearCache() async {
    workouts = []; days = []; _routes.clear(); tracks.clear(); _noTrack.clear(); lastSync = null;
    for (final name in ['hs_cache.json', 'hs_tracks.json']) {
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
