// Dart <-> Health Connect (Google Health) bridge + JSON disk cache.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
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
  final Map<String, List<RoutePoint>> _routes = {};

  Future<void> init() async {
    await _loadCache();
    await refreshStatus();
    if (permitted) sync();
  }

  Future<void> refreshStatus() async {
    try {
      final s = await _ch.invokeMethod<String>('status');
      status = switch (s) { 'available' => HcStatus.available, 'update_required' => HcStatus.updateRequired, _ => HcStatus.unavailable };
      if (status == HcStatus.available) {
        final g = (await _ch.invokeMethod<List>('granted'))?.cast<String>() ?? [];
        permitted = g.any((p) => p.endsWith('READ_EXERCISE'));
      }
    } catch (e) { error = '$e'; }
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    try {
      final g = (await _ch.invokeMethod<List>('requestPermissions'))?.cast<String>() ?? [];
      permitted = g.any((p) => p.endsWith('READ_EXERCISE'));
      notifyListeners();
      if (permitted) await sync();
    } catch (e) { error = '$e'; notifyListeners(); }
    return permitted;
  }

  Future<void> openHealthConnect() async { try { await _ch.invokeMethod('openSettings'); } catch (_) {} }

  /// Sync: last 400 days of workouts + 400 days of daily totals.
  Future<void> sync({int daysBack = 400}) async {
    if (loading || !permitted) return;
    loading = true; error = null; notifyListeners();
    try {
      final end = DateTime.now().millisecondsSinceEpoch;
      final start = DateTime.now().subtract(Duration(days: daysBack)).millisecondsSinceEpoch;
      final a = {'start': start, 'end': end};
      final ws = (await _ch.invokeMethod<List>('sessions', a)) ?? [];
      final ds = (await _ch.invokeMethod<List>('daily', a)) ?? [];
      workouts = ws.map((e) => Workout.fromMap(Map.from(e as Map))).toList()
        ..sort((x, y) => y.start.compareTo(x.start));
      days = ds.map((e) => DayStat.fromMap(Map.from(e as Map))).toList()
        ..sort((x, y) => x.day.compareTo(y.day));
      lastSync = DateTime.now();
      await _saveCache();
    } on PlatformException catch (e) { error = e.message ?? e.code; }
    catch (e) { error = '$e'; }
    loading = false; notifyListeners();
  }

  Future<List<RoutePoint>> route(Workout w) async {
    if (_routes.containsKey(w.id)) return _routes[w.id]!;
    try {
      final r = (await _ch.invokeMethod<List>('route', {'id': w.id})) ?? [];
      final pts = r.map((e) {
        final l = (e as List).cast<num>();
        return RoutePoint(LatLng(l[0].toDouble(), l[1].toDouble()), l[2].toDouble(),
            DateTime.fromMillisecondsSinceEpoch(l[3].toInt()));
      }).toList();
      _routes[w.id] = pts;
      return pts;
    } catch (_) { return []; }
  }

  /// Heart-rate curve: [(time, bpm)].
  Future<List<(DateTime, int)>> heartRate(Workout w) async {
    try {
      final r = (await _ch.invokeMethod<List>('heartRate',
              {'start': w.start.millisecondsSinceEpoch, 'end': w.end.millisecondsSinceEpoch})) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toInt()); }).toList();
    } catch (_) { return []; }
  }

  Future<List<(DateTime, double)>> weights() async {
    try {
      final r = (await _ch.invokeMethod<List>('weight', {
            'start': DateTime.now().subtract(const Duration(days: 400)).millisecondsSinceEpoch,
            'end': DateTime.now().millisecondsSinceEpoch})) ?? [];
      return r.map((e) { final l = (e as List).cast<num>();
        return (DateTime.fromMillisecondsSinceEpoch(l[0].toInt()), l[1].toDouble()); }).toList();
    } catch (_) { return []; }
  }

  // ── Disk cache ──
  Future<File> get _file async => File('${(await getApplicationSupportDirectory()).path}/hs_cache.json');
  Future<void> _saveCache() async {
    try {
      await (await _file).writeAsString(jsonEncode({
        'sync': lastSync?.millisecondsSinceEpoch,
        'w': workouts.map((w) => w.toMap()).toList(), 'd': days.map((d) => d.toMap()).toList()}));
    } catch (_) {}
  }
  Future<void> _loadCache() async {
    try {
      final f = await _file; if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map;
      workouts = (j['w'] as List).map((e) => Workout.fromMap(e as Map)).toList();
      days = (j['d'] as List).map((e) => DayStat.fromMap(e as Map)).toList();
      if (j['sync'] != null) lastSync = DateTime.fromMillisecondsSinceEpoch(j['sync'] as int);
    } catch (_) {}
  }
  Future<void> clearCache() async {
    workouts = []; days = []; _routes.clear(); lastSync = null;
    try { await (await _file).delete(); } catch (_) {}
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
