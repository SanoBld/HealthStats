// Modèles + métadonnées des types d'exercice Health Connect.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class SportInfo {
  final String fr, en;
  final IconData icon;
  final Color color;
  final bool strength; // séance de muscu (affiche séries/répétitions)
  final bool outdoor;  // a normalement un tracé GPS
  const SportInfo(this.fr, this.en, this.icon, this.color, {this.strength = false, this.outdoor = false});
}

// Constantes ExerciseSessionRecord.EXERCISE_TYPE_*
const Map<int, SportInfo> kSports = {
  56: SportInfo('Course', 'Running', Icons.directions_run_rounded, Color(0xFFFF2020), outdoor: true),
  57: SportInfo('Course (tapis)', 'Treadmill', Icons.directions_run_rounded, Color(0xFFFF5A5A)),
  79: SportInfo('Marche', 'Walking', Icons.directions_walk_rounded, Color(0xFF34C759), outdoor: true),
  37: SportInfo('Randonnée', 'Hiking', Icons.hiking_rounded, Color(0xFF2E9E5B), outdoor: true),
  8: SportInfo('Vélo', 'Cycling', Icons.directions_bike_rounded, Color(0xFFFFC700), outdoor: true),
  9: SportInfo('Vélo d\'appart.', 'Stationary bike', Icons.pedal_bike_rounded, Color(0xFFFFD84D)),
  74: SportInfo('Natation', 'Swimming', Icons.pool_rounded, Color(0xFF2D9CDB)),
  73: SportInfo('Nage en eau libre', 'Open water', Icons.pool_rounded, Color(0xFF2D9CDB), outdoor: true),
  70: SportInfo('Musculation', 'Strength', Icons.fitness_center_rounded, Color(0xFFB36BFF), strength: true),
  81: SportInfo('Haltérophilie', 'Weightlifting', Icons.fitness_center_rounded, Color(0xFFB36BFF), strength: true),
  83: SportInfo('Yoga', 'Yoga', Icons.self_improvement_rounded, Color(0xFFFF8FB1)),
  36: SportInfo('HIIT', 'HIIT', Icons.local_fire_department_rounded, Color(0xFFFF7A00)),
  53: SportInfo('Aviron', 'Rowing', Icons.rowing_rounded, Color(0xFF00B8A9), outdoor: true),
  25: SportInfo('Elliptique', 'Elliptical', Icons.directions_run_rounded, Color(0xFF8E8E93)),
  2: SportInfo('Badminton', 'Badminton', Icons.sports_tennis_rounded, Color(0xFF5AC8FA)),
  10: SportInfo('Football US', 'American football', Icons.sports_football_rounded, Color(0xFF8B5A2B)),
  64: SportInfo('Football', 'Soccer', Icons.sports_soccer_rounded, Color(0xFF30B050), outdoor: true),
  5: SportInfo('Basket', 'Basketball', Icons.sports_basketball_rounded, Color(0xFFFF8A00)),
  0: SportInfo('Autre', 'Workout', Icons.bolt_rounded, Color(0xFF8E8E93)),
};
SportInfo sportOf(int t) => kSports[t] ?? kSports[0]!;

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
  Duration get duration => end.difference(start);
  double get kcal => activeKcal > 0 ? activeKcal : totalKcal;
  /// Allure min/km (course/marche) ou null.
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

// ── Formatage ───────────────────────────────────────────────────────────
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
}
String fmtKm(double m) => (m / 1000).toStringAsFixed(m >= 10000 ? 1 : 2);
String fmtPace(double? p) {
  if (p == null || p.isNaN || p.isInfinite) return '—';
  final min = p.floor(), sec = ((p - min) * 60).round();
  return "$min'${sec.toString().padLeft(2, '0')}\"";
}
