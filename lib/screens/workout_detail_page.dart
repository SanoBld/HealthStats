// Workout detail: GPS map, stats, heart-rate curve, elevation, strength sets.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';

/// Tile layer matching the theme (OSM light / CARTO dark).
Widget hsTileLayer(BuildContext c) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  return TileLayer(
    urlTemplate: dark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: dark ? const ['a', 'b', 'c'] : const [],
    userAgentPackageName: 'com.healthstats.app',
  );
}

class WorkoutDetailPage extends StatefulWidget {
  final Workout workout;
  const WorkoutDetailPage({super.key, required this.workout});
  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  List<RoutePoint> _route = [];
  List<(DateTime, int)> _hr = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final hs = HealthService.instance, w = widget.workout;
    Future.wait([if (w.hasRoute) hs.route(w) else Future.value(<RoutePoint>[]), hs.heartRate(w)]).then((r) {
      if (!mounted) return;
      setState(() { _route = r[0] as List<RoutePoint>; _hr = r[1] as List<(DateTime, int)>; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workout, sp = w.sport, s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final pts = _route.map((p) => p.pos).toList();
    final alts = _route.map((p) => p.alt).where((a) => !a.isNaN).toList();
    return Scaffold(
      appBar: AppBar(title: Text(w.title.isNotEmpty ? w.title : sportName(sp))),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        if (pts.length > 1) SizedBox(height: 280, child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ClipRRect(borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(36))),
              children: [
                hsTileLayer(context),
                PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 5, color: sp.color, borderStrokeWidth: 2, borderColor: Colors.black54)]),
                MarkerLayer(markers: [
                  Marker(point: pts.first, width: 18, height: 18, child: const _Dot(Colors.green)),
                  Marker(point: pts.last, width: 18, height: 18, child: const _Dot(Colors.red)),
                ]),
                const SimpleAttributionWidget(source: Text('© OpenStreetMap · CARTO')),
              ],
            )),
          )))
        else if (_loading && w.hasRoute) const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Row(children: [
          Icon(sp.icon, color: sp.color), const SizedBox(width: 8),
          Expanded(child: Text('${sportName(sp)} · ${fmtDate(w.start)}', style: t.titleMedium)),
        ])),
        if (w.notes.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(w.notes, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
        const SizedBox(height: 12),
        StatGrid([
          StatTile(icon: Icons.timer_rounded, value: fmtDuration(w.duration), label: isFr ? 'Durée' : 'Duration', color: sp.color),
          if (w.distanceM > 100) StatTile(icon: Icons.route_rounded, value: distLabel(w.distanceM), label: 'Distance', color: sp.color),
          if (w.paceMinKm != null && (w.type == 56 || w.type == 79 || w.type == 37 || w.type == 57))
            StatTile(icon: Icons.speed_rounded, value: fmtPace(w.paceMinKm), label: isFr ? 'Allure /km' : 'Pace /km', color: sp.color),
          if (w.speedKmh != null && w.type == 8) StatTile(icon: Icons.speed_rounded, value: '${w.speedKmh!.toStringAsFixed(1)} km/h', label: isFr ? 'Vitesse moy.' : 'Avg speed', color: sp.color),
          if (w.kcal > 0) StatTile(icon: Icons.local_fire_department_rounded, value: '${w.kcal.round()}', label: 'kcal', color: sp.color),
          if (w.steps > 0) StatTile(icon: Icons.directions_walk_rounded, value: '${w.steps}', label: isFr ? 'Pas' : 'Steps', color: sp.color),
          if (w.hrAvg > 0) StatTile(icon: Icons.favorite_rounded, value: '${w.hrAvg.round()} bpm', label: isFr ? 'FC moyenne' : 'Avg HR', color: sp.color),
          if (w.hrMax > 0) StatTile(icon: Icons.monitor_heart_rounded, value: '${w.hrMax.round()} bpm', label: isFr ? 'FC max' : 'Max HR', color: sp.color),
          if (alts.length > 1) StatTile(icon: Icons.terrain_rounded, value: '+${_gain(alts).round()} m', label: isFr ? 'Dénivelé +' : 'Elevation +', color: sp.color),
        ]),
        if (_hr.length > 1) ...[
          SectionTitle(isFr ? 'Fréquence cardiaque' : 'Heart rate'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: LineSpark(values: _hr.map((e) => e.$2.toDouble()).toList(), color: s.primary)),
        ],
        if (alts.length > 1) ...[
          SectionTitle(isFr ? 'Altitude' : 'Elevation'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: LineSpark(values: alts, color: sp.color)),
        ],
        if (sp.strength) ...[
          SectionTitle(isFr ? 'Séries' : 'Sets'),
          if (w.segments.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(isFr
                ? 'Pas de détail par exercice dans Health Connect pour cette séance.'
                : 'No per-exercise detail in Health Connect for this session.'))
          else for (var i = 0; i < w.segments.length; i++) ListTile(
            leading: CircleAvatar(backgroundColor: sp.color.withValues(alpha: 0.2), child: Text('${i + 1}')),
            title: Text(w.segments[i].reps > 0 ? '${w.segments[i].reps} ${isFr ? 'répétitions' : 'reps'}' : (isFr ? 'Série' : 'Set')),
            subtitle: Text(fmtDuration(w.segments[i].end.difference(w.segments[i].start))),
          ),
        ],
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('${isFr ? 'Source' : 'Source'} : ${w.source}', style: t.labelSmall?.copyWith(color: s.onSurfaceVariant))),
      ]),
    );
  }

  double _gain(List<double> a) { var g = 0.0; for (var i = 1; i < a.length; i++) { if (a[i] > a[i - 1]) g += a[i] - a[i - 1]; } return g; }
}

class _Dot extends StatelessWidget {
  final Color c; const _Dot(this.c);
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)));
}
