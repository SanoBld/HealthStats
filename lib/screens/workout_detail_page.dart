// Workout detail: GPS map, stats, touchable heart-rate / speed / elevation charts, zones, sets.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/skeleton.dart' show M3LoadingIndicator;

/// Map tiles: OpenStreetMap (no API key). In dark mode the tiles are inverted.
Widget hsTileLayer(BuildContext c) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.healthstats.app',
    tileBuilder: dark ? darkModeTileBuilder : null,
  );
}

class WorkoutDetailPage extends StatefulWidget {
  final Workout workout;
  const WorkoutDetailPage({super.key, required this.workout});
  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  // Calm sports: HR zones make no sense
  static const _calm = {79, 83, 71, 48, 33};
  List<RoutePoint> _route = [];
  List<(DateTime, int)> _hr = [];
  bool _loading = true;
  LatLng? _cur; // point shown on the map while touching a chart

  @override
  void initState() {
    super.initState();
    final hs = HealthService.instance, w = widget.workout;
    Future.wait([if (w.hasRoute) hs.route(w, ask: true) else Future.value(<RoutePoint>[]), hs.heartRate(w)]).then((r) {
      if (!mounted) return;
      setState(() { _route = r[0] as List<RoutePoint>; _hr = r[1] as List<(DateTime, int)>; _loading = false; });
    });
  }

  String _clock(Duration d) {
    final m = d.inMinutes, sec = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Smoothed speed (km/h) along the route.
  List<double> _speeds() {
    if (_route.length < 6) return [];
    const d = Distance();
    final raw = <double>[0];
    for (var i = 1; i < _route.length; i++) {
      final dt = _route[i].time.difference(_route[i - 1].time).inMilliseconds / 1000;
      final m = d.as(LengthUnit.Meter, _route[i - 1].pos, _route[i].pos);
      raw.add(dt > 0 ? (m / dt) * 3.6 : raw.last);
    }
    final out = <double>[];
    for (var i = 0; i < raw.length; i++) {
      final a = i - 4 < 0 ? 0 : i - 4, b = i + 4 > raw.length - 1 ? raw.length - 1 : i + 4;
      var sum = 0.0;
      for (var k = a; k <= b; k++) { sum += raw[k]; }
      out.add(sum / (b - a + 1));
    }
    return out;
  }

  void _routeCursor(double? f) {
    if (_route.isEmpty) return;
    setState(() => _cur = f == null ? null : _route[(f * (_route.length - 1)).round()].pos);
  }

  void _hrCursor(double? f) {
    if (_route.isEmpty || _hr.isEmpty) return;
    if (f == null) { setState(() => _cur = null); return; }
    final t = _hr[(f * (_hr.length - 1)).round()].$1;
    var best = 0, bestD = 1 << 62;
    for (var i = 0; i < _route.length; i++) {
      final dd = _route[i].time.difference(t).inMilliseconds.abs();
      if (dd < bestD) { bestD = dd; best = i; }
    }
    setState(() => _cur = _route[best].pos);
  }

  /// Seconds spent in each of 5 heart-rate zones (% of max HR; max from the birth date).
  List<double> _zones(int maxHr) {
    final z = List<double>.filled(5, 0);
    for (var i = 0; i < _hr.length - 1; i++) {
      final dt = (_hr[i + 1].$1.difference(_hr[i].$1).inSeconds.clamp(0, 30) as int).toDouble();
      final p = _hr[i].$2 / maxHr;
      z[p < 0.6 ? 0 : p < 0.7 ? 1 : p < 0.8 ? 2 : p < 0.9 ? 3 : 4] += dt;
    }
    return z;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workout, sp = w.sport, col = sportColor(context, sp);
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final pts = _route.map((p) => p.pos).toList();
    final alts = _route.map((p) => p.alt).where((a) => !a.isNaN).toList();
    final speeds = _speeds();
    final birth = parseBirth(profileBirthNotifier.value);
    final age = birth == null ? null : (DateTime.now().difference(birth).inDays / 365.25).floor();
    final maxHr = age != null ? 220 - age : (w.hrMax > 0 ? w.hrMax.round() : 190);
    return Scaffold(
      appBar: AppBar(title: Text(w.title.isNotEmpty ? w.title : sportName(sp))),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        if (pts.length > 1) SizedBox(height: 280, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(36))),
              children: [
                hsTileLayer(context),
                PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 5, color: col, borderStrokeWidth: 2, borderColor: Colors.black54)]),
                MarkerLayer(markers: [
                  Marker(point: pts.first, width: 18, height: 18, child: const _Dot(Colors.green)),
                  Marker(point: pts.last, width: 18, height: 18, child: const _Dot(Colors.red)),
                  if (_cur != null) Marker(point: _cur!, width: 26, height: 26, child: _Dot(col)),
                ]),
                const SimpleAttributionWidget(source: Text('OpenStreetMap')),
              ],
            ))))
        else if (_loading && w.hasRoute) const SizedBox(height: 120, child: Center(child: M3LoadingIndicator(size: 56))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Row(children: [
          Icon(sp.icon, color: col), const SizedBox(width: 8),
          Expanded(child: Text('${sportName(sp)} · ${fmtDate(w.start)}', style: t.titleMedium)),
        ])),
        if (w.notes.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(w.notes, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
        const SizedBox(height: 12),
        StatGrid([
          StatTile(icon: Icons.timer_rounded, value: fmtDuration(w.duration), label: isFr ? 'Durée' : 'Duration', color: col),
          if (w.distanceM > 100) StatTile(icon: Icons.route_rounded, value: distLabel(w.distanceM), label: 'Distance', color: col),
          if (w.paceMinKm != null && (w.type == 56 || w.type == 79 || w.type == 37 || w.type == 57))
            StatTile(icon: Icons.speed_rounded, value: fmtPace(w.paceMinKm), label: isFr ? 'Allure /km' : 'Pace /km', color: col),
          if (w.speedKmh != null && w.type != 56 && w.type != 79 && w.type != 37 && w.type != 57)
            StatTile(icon: Icons.speed_rounded, value: '${w.speedKmh!.toStringAsFixed(1)} km/h', label: isFr ? 'Vitesse moy.' : 'Avg speed', color: col),
          if (w.kcal > 0) StatTile(icon: Icons.local_fire_department_rounded, value: '${w.kcal.round()}', label: 'kcal', color: col),
          if (w.steps > 0) StatTile(icon: Icons.directions_walk_rounded, value: '${w.steps}', label: isFr ? 'Pas' : 'Steps', color: col),
          if (w.hrAvg > 0) StatTile(icon: Icons.favorite_rounded, value: '${w.hrAvg.round()} bpm', label: isFr ? 'FC moyenne' : 'Avg HR', color: col),
          if (w.hrMax > 0) StatTile(icon: Icons.monitor_heart_rounded, value: '${w.hrMax.round()} bpm', label: isFr ? 'FC max' : 'Max HR', color: col),
          if (alts.length > 1) StatTile(icon: Icons.terrain_rounded, value: '+${_gain(alts).round()} m', label: isFr ? 'Dénivelé +' : 'Elevation +', color: col),
        ]),
        if (_hr.length > 1) ...[
          SectionTitle(isFr ? 'Fréquence cardiaque' : 'Heart rate'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: _hr.map((e) => e.$2.toDouble()).toList(), color: s.primary, unit: 'bpm',
              labelOf: (i) => _clock(_hr[i].$1.difference(w.start)), onScrub: _hrCursor)),
          if (!_calm.contains(w.type)) ...[
            SectionTitle(isFr ? 'Zones de FC' : 'HR zones'),
            ..._zoneRows(context, _zones(maxHr), col),
          ],
        ],
        if (alts.length > 1) ...[
          SectionTitle(isFr ? 'Altitude' : 'Elevation'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: alts, color: col, unit: 'm', onScrub: _routeCursor)),
        ],
        if (speeds.length > 1) ...[
          SectionTitle(isFr ? 'Vitesse' : 'Speed'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: speeds, color: col, unit: 'km/h', decimals: 1, onScrub: _routeCursor)),
        ],
        if (sp.strength) ...[
          SectionTitle(isFr ? 'Séries' : 'Sets'),
          if (w.segments.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isFr
                ? 'Pas de détail par exercice dans Health Connect pour cette séance.'
                : 'No per-exercise detail in Health Connect for this session.'))
          else for (var i = 0; i < w.segments.length; i++) ListTile(
            leading: CircleAvatar(backgroundColor: col.withValues(alpha: 0.2), child: Text('${i + 1}')),
            title: Text(w.segments[i].reps > 0 ? '${w.segments[i].reps} ${isFr ? 'répétitions' : 'reps'}' : (isFr ? 'Série' : 'Set')),
            subtitle: Text(fmtDuration(w.segments[i].end.difference(w.segments[i].start))),
          ),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('Source : ${w.sourceName}', style: t.labelSmall?.copyWith(color: s.onSurfaceVariant))),
      ]),
    );
  }

  List<Widget> _zoneRows(BuildContext c, List<double> z, Color col) {
    final total = z.fold(0.0, (a, b) => a + b);
    if (total <= 0) return [];
    const names = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    return [
      for (var i = 0; i < 5; i++) Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(children: [
          SizedBox(width: 30, child: Text(names[i], style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: z[i] / total, minHeight: 10, color: col, backgroundColor: col.withValues(alpha: 0.15)))),
          SizedBox(width: 92, child: Text('${_clock(Duration(seconds: z[i].round()))} · ${(z[i] / total * 100).round()}%',
              textAlign: TextAlign.end, style: Theme.of(c).textTheme.labelMedium)),
        ]),
      ),
    ];
  }

  double _gain(List<double> a) { var g = 0.0; for (var i = 1; i < a.length; i++) { if (a[i] > a[i - 1]) g += a[i] - a[i - 1]; } return g; }
}

class _Dot extends StatelessWidget {
  final Color c; const _Dot(this.c);
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)));
}
