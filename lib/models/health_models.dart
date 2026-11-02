// Models + metadata for Health Connect exercise types.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class SportInfo {
  final String fr, en;
  final IconData icon;
  final Color color;
  final bool strength; // strength session (shows sets/reps)
  final bool outdoor;  // normally has a GPS route
  const SportInfo(this.fr, this.en, this.icon, this.color, {this.strength = false, this.outdoor = false});
}

// Constants from ExerciseSessionRecord.EXERCISE_TYPE_* (all Health Connect types)
const Map<int, SportInfo> kSports = {
  56: SportInfo('Course', 'Running', Icons.directions_run_rounded, Color(0xFFFF2020), outdoor: true),
  57: SportInfo('Course (tapis)', 'Treadmill', Icons.directions_run_rounded, Color(0xFFFF5A5A)),
  79: SportInfo('Marche', 'Walking', Icons.directions_walk_rounded, Color(0xFF34C759), outdoor: true),
  37: SportInfo('Randonnée', 'Hiking', Icons.hiking_rounded, Color(0xFF2E9E5B), outdoor: true),
  8: SportInfo('Vélo', 'Cycling', Icons.directions_bike_rounded, Color(0xFFFFC700), outdoor: true),
  9: SportInfo('Vélo d\'appart.', 'Stationary bike', Icons.pedal_bike_rounded, Color(0xFFFFD84D)),
  74: SportInfo('Natation', 'Swimming', Icons.pool_rounded, Color(0xFF2D9CDB)),
  73: SportInfo('Nage en eau libre', 'Open water', Icons.pool_rounded, Color(0xFF1E88C8), outdoor: true),
  70: SportInfo('Musculation', 'Strength', Icons.fitness_center_rounded, Color(0xFFB36BFF), strength: true),
  81: SportInfo('Haltérophilie', 'Weightlifting', Icons.fitness_center_rounded, Color(0xFF9B51E0), strength: true),
  13: SportInfo('Callisthénie', 'Calisthenics', Icons.accessibility_new_rounded, Color(0xFFA56EFF), strength: true),
  83: SportInfo('Yoga', 'Yoga', Icons.self_improvement_rounded, Color(0xFFFF8FB1)),
  48: SportInfo('Pilates', 'Pilates', Icons.self_improvement_rounded, Color(0xFFFFA3C4)),
  71: SportInfo('Étirements', 'Stretching', Icons.spa_rounded, Color(0xFFFFB3D1)),
  33: SportInfo('Respiration guidée', 'Guided breathing', Icons.spa_rounded, Color(0xFF9AD4D6)),
  36: SportInfo('HIIT', 'HIIT', Icons.local_fire_department_rounded, Color(0xFFFF7A00)),
  10: SportInfo('Boot camp', 'Boot camp', Icons.local_fire_department_rounded, Color(0xFFFF8F3A)),
  26: SportInfo('Cours collectif', 'Exercise class', Icons.groups_rounded, Color(0xFFFF9E40)),
  16: SportInfo('Danse', 'Dancing', Icons.music_note_rounded, Color(0xFFE91E8C)),
  53: SportInfo('Aviron', 'Rowing', Icons.rowing_rounded, Color(0xFF00B8A9), outdoor: true),
  54: SportInfo('Rameur', 'Rowing machine', Icons.rowing_rounded, Color(0xFF26C6B8)),
  25: SportInfo('Elliptique', 'Elliptical', Icons.directions_run_rounded, Color(0xFF8E8E93)),
  68: SportInfo('Escaliers', 'Stair climbing', Icons.stairs_rounded, Color(0xFF8E8E93)),
  69: SportInfo('Simulateur d\'escaliers', 'Stair machine', Icons.stairs_rounded, Color(0xFF9E9EA3)),
  51: SportInfo('Escalade', 'Rock climbing', Icons.terrain_rounded, Color(0xFF8D6E63), outdoor: true),
  46: SportInfo('Paddle / canoë', 'Paddling', Icons.kayaking_rounded, Color(0xFF00ACC1), outdoor: true),
  58: SportInfo('Voile', 'Sailing', Icons.sailing_rounded, Color(0xFF29B6F6), outdoor: true),
  59: SportInfo('Plongée', 'Scuba diving', Icons.pool_rounded, Color(0xFF0277BD)),
  72: SportInfo('Surf', 'Surfing', Icons.surfing_rounded, Color(0xFF26A69A), outdoor: true),
  80: SportInfo('Water-polo', 'Water polo', Icons.pool_rounded, Color(0xFF42A5F5)),
  47: SportInfo('Parapente', 'Paragliding', Icons.paragliding_rounded, Color(0xFF7E57C2), outdoor: true),
  61: SportInfo('Ski', 'Skiing', Icons.downhill_skiing_rounded, Color(0xFF4FC3F7), outdoor: true),
  62: SportInfo('Snowboard', 'Snowboarding', Icons.snowboarding_rounded, Color(0xFF4DD0E1), outdoor: true),
  63: SportInfo('Raquettes', 'Snowshoeing', Icons.snowshoeing_rounded, Color(0xFF80DEEA), outdoor: true),
  39: SportInfo('Patinage sur glace', 'Ice skating', Icons.ice_skating_rounded, Color(0xFF81D4FA), outdoor: true),
  60: SportInfo('Patin / roller', 'Skating', Icons.roller_skating_rounded, Color(0xFFFF6E40), outdoor: true),
  38: SportInfo('Hockey sur glace', 'Ice hockey', Icons.sports_hockey_rounded, Color(0xFF64B5F6)),
  52: SportInfo('Roller hockey', 'Roller hockey', Icons.sports_hockey_rounded, Color(0xFFFF8A65)),
  2: SportInfo('Badminton', 'Badminton', Icons.sports_tennis_rounded, Color(0xFF5AC8FA)),
  75: SportInfo('Tennis de table', 'Table tennis', Icons.sports_tennis_rounded, Color(0xFF4DB6AC)),
  76: SportInfo('Tennis', 'Tennis', Icons.sports_tennis_rounded, Color(0xFFC6E03A)),
  66: SportInfo('Squash', 'Squash', Icons.sports_tennis_rounded, Color(0xFFAED581)),
  50: SportInfo('Racquetball', 'Racquetball', Icons.sports_tennis_rounded, Color(0xFFDCE775)),
  28: SportInfo('Football US', 'American football', Icons.sports_football_rounded, Color(0xFF8B5A2B)),
  29: SportInfo('Football australien', 'Australian football', Icons.sports_football_rounded, Color(0xFFA1887F)),
  64: SportInfo('Football', 'Soccer', Icons.sports_soccer_rounded, Color(0xFF30B050), outdoor: true),
  55: SportInfo('Rugby', 'Rugby', Icons.sports_rugby_rounded, Color(0xFF6D4C41)),
  5: SportInfo('Basket', 'Basketball', Icons.sports_basketball_rounded, Color(0xFFFF8A00)),
  78: SportInfo('Volley', 'Volleyball', Icons.sports_volleyball_rounded, Color(0xFFFFB74D)),
  35: SportInfo('Handball', 'Handball', Icons.sports_handball_rounded, Color(0xFFEF6C00)),
  4: SportInfo('Baseball', 'Baseball', Icons.sports_baseball_rounded, Color(0xFFD32F2F)),
  65: SportInfo('Softball', 'Softball', Icons.sports_baseball_rounded, Color(0xFFE57373)),
  14: SportInfo('Cricket', 'Cricket', Icons.sports_cricket_rounded, Color(0xFF66BB6A)),
  32: SportInfo('Golf', 'Golf', Icons.sports_golf_rounded, Color(0xFF43A047), outdoor: true),
  31: SportInfo('Frisbee', 'Frisbee', Icons.sports_rounded, Color(0xFFFFCA28), outdoor: true),
  11: SportInfo('Boxe', 'Boxing', Icons.sports_mma_rounded, Color(0xFFC62828)),
  44: SportInfo('Arts martiaux', 'Martial arts', Icons.sports_martial_arts_rounded, Color(0xFFAD1457)),
  27: SportInfo('Escrime', 'Fencing', Icons.sports_martial_arts_rounded, Color(0xFF880E4F)),
  34: SportInfo('Gymnastique', 'Gymnastics', Icons.sports_gymnastics_rounded, Color(0xFFBA68C8)),
  82: SportInfo('Fauteuil roulant', 'Wheelchair', Icons.accessible_rounded, Color(0xFF5C6BC0), outdoor: true),
  0: SportInfo('Autre', 'Workout', Icons.bolt_rounded, Color(0xFF8E8E93)),
};
SportInfo sportOf(int t) => kSports[t] ?? kSports[0]!;

/// Friendly name of the app that wrote a session (from its package name).
/// Real app names read from Android (filled after the sync).
final Map<String, String> kAppLabels = {};

String sourceLabel(String pkg) {
  if (pkg.isEmpty) return '—';
  final real = kAppLabels[pkg];
  if (real != null && real.isNotEmpty) return real;
  const known = {
    'com.google.android.apps.fitness': 'Google Fit',
    'com.google.android.apps.healthdata': 'Health Connect',
    'com.sec.android.app.shealth': 'Samsung Health',
    'com.garmin.android.apps.connectmobile': 'Garmin Connect',
    'com.strava': 'Strava',
    'com.fitbit.FitbitMobile': 'Fitbit',
    'com.huawei.health': 'Huawei Health',
    'com.xiaomi.wearable': 'Mi Fitness',
    'com.mi.health': 'Mi Fitness',
    'com.zepp.health': 'Zepp',
    'com.huami.watch.hmwatchmanager': 'Zepp',
    'com.heytap.health': 'HeyTap Health',
    'com.polar.polarflow': 'Polar Flow',
    'com.suunto.connectivity.suuntoconnectivity': 'Suunto',
    'com.nike.plusgps': 'Nike Run Club',
    'com.runtastic.android': 'Adidas Running',
    'com.ouraring.oura': 'Oura',
    'com.whoop.android': 'WHOOP',
    'com.wahoofitness.fitness': 'Wahoo',
    'com.onepeloton.callisto': 'Peloton',
    'com.myfitnesspal.android': 'MyFitnessPal',
    'com.komoot.android': 'Komoot',
    'com.mapmyrun.android2': 'MapMyRun',
    'com.hevy': 'Hevy',
    'com.withings.wiscale2': 'Withings',
    'com.coros.coros': 'COROS',
    'com.sec.android.app.shealth.wearable': 'Galaxy Watch',
    'com.google.android.wearable.healthservices': 'Wear OS',
    'com.healthstats.app': 'HealthStats',
    'import': 'Import GPX/FIT',
  };
  final k = known[pkg];
  if (k != null) return k;
  final parts = pkg.split('.').where((e) => e.isNotEmpty && e != 'android' && e != 'app' && e != 'apps' && e != 'mobile').toList();
  final last = parts.isEmpty ? pkg : parts.last;
  return last.isEmpty ? pkg : last[0].toUpperCase() + last.substring(1);
}

class Segment {
  final int type; final DateTime start, end; final int reps;
  Segment(this.type, this.start, this.end, this.reps);
  factory Segment.fromMap(Map m) => Segment(m['type'] as int,
      DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
      DateTime.fromMillisecondsSinceEpoch(m['end'] as int), (m['reps'] as int?) ?? 0);
  Map<String, dynamic> toMap() => {'type': type, 'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch, 'reps': reps};
}

class Workout {
  final String id; final int type; final String title, notes, source;
  final DateTime start, end; final bool hasRoute;
  final double distanceM, activeKcal, totalKcal; final int steps;
  final double hrAvg, hrMax, hrMin; final List<Segment> segments;
  Workout({required this.id, required this.type, required this.title, required this.notes,
      required this.source, required this.start, required this.end, required this.hasRoute,
      required this.distanceM, required this.activeKcal, required this.totalKcal,
      required this.steps, required this.hrAvg, required this.hrMax, required this.hrMin,
      required this.segments});

  SportInfo get sport => sportOf(type);
  String get sourceName => sourceLabel(source);
  /// Real sport name from Health Connect, or the session title if the type is unknown.
  bool get unknownType => !kSports.containsKey(type);
  Duration get duration => end.difference(start);
  double get kcal => activeKcal > 0 ? activeKcal : totalKcal;
  /// Pace in min/km (running/walking) or null.
  double? get paceMinKm => distanceM > 100 ? duration.inSeconds / 60 / (distanceM / 1000) : null;
  double? get speedKmh => distanceM > 100 ? (distanceM / 1000) / (duration.inSeconds / 3600) : null;
  int get totalReps => segments.fold(0, (a, s) => a + s.reps);

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  factory Workout.fromMap(Map m) => Workout(
        id: m['id'] as String, type: (m['type'] as int?) ?? 0,
        title: (m['title'] as String?) ?? '', notes: (m['notes'] as String?) ?? '',
        source: (m['source'] as String?) ?? '',
        start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(m['end'] as int),
        hasRoute: m['hasRoute'] == true,
        distanceM: _d(m['distanceM']), activeKcal: _d(m['activeKcal']), totalKcal: _d(m['totalKcal']),
        steps: (m['steps'] as num?)?.toInt() ?? 0,
        hrAvg: _d(m['hrAvg']), hrMax: _d(m['hrMax']), hrMin: _d(m['hrMin']),
        segments: ((m['segments'] as List?) ?? const []).map((e) => Segment.fromMap(e as Map)).toList(),
      );
  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'title': title, 'notes': notes,
      'source': source, 'start': start.millisecondsSinceEpoch, 'end': end.millisecondsSinceEpoch,
      'hasRoute': hasRoute, 'distanceM': distanceM, 'activeKcal': activeKcal, 'totalKcal': totalKcal,
      'steps': steps, 'hrAvg': hrAvg, 'hrMax': hrMax, 'hrMin': hrMin,
      'segments': segments.map((s) => s.toMap()).toList()};
}

class DayStat {
  final DateTime day; final int steps; final double distanceM, activeKcal, totalKcal, hrAvg;
  DayStat(this.day, this.steps, this.distanceM, this.activeKcal, this.totalKcal, this.hrAvg);
  factory DayStat.fromMap(Map m) => DayStat(
      DateTime.fromMillisecondsSinceEpoch(m['day'] as int), (m['steps'] as num?)?.toInt() ?? 0,
      Workout._d(m['distanceM']), Workout._d(m['activeKcal']), Workout._d(m['totalKcal']), Workout._d(m['hrAvg']));
  Map<String, dynamic> toMap() => {'day': day.millisecondsSinceEpoch, 'steps': steps,
      'distanceM': distanceM, 'activeKcal': activeKcal, 'totalKcal': totalKcal, 'hrAvg': hrAvg};
}

class RoutePoint {
  final LatLng pos; final double alt; final DateTime time;
  RoutePoint(this.pos, this.alt, this.time);
}

// ── Formatting ───────────────────────────────────────────────────────────
/// 45 s · 7 min 30 s · 42 min · 1 h 05 min (right unit for the size)
String fmtDuration(Duration d) {
  final sec = d.inSeconds;
  if (sec < 60) return '$sec s';
  final h = d.inHours, m = d.inMinutes % 60, s = sec % 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  return d.inMinutes < 10 && s > 0 ? '$m min ${s.toString().padLeft(2, '0')} s' : '$m min';
}
/// Clock style for chart cursors: 4:05 or 1:04:05
String fmtClock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '${d.inMinutes}:$ss';
}
String fmtKm(double m) => (m / 1000).toStringAsFixed(m >= 10000 ? 1 : 2);
String fmtPace(double? p) {
  if (p == null || p.isNaN || p.isInfinite) return '—';
  final min = p.floor(), sec = ((p - min) * 60).round();
  return "$min'${sec.toString().padLeft(2, '0')}\"";
}
