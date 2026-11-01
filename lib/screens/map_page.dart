// Map tab: all recent GPS routes on one map.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import 'workout_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _ctrl = MapController();
  int _days = 30;
  bool _loading = false;
  final Map<String, List<LatLng>> _tracks = {};
  Workout? _sel;
  int _stamp = -1;

  Future<void> _load(List<Workout> ws) async {
    setState(() => _loading = true);
    final hs = HealthService.instance;
    for (final w in ws.take(40)) {
      if (_tracks.containsKey(w.id)) continue;
      final r = await hs.route(w);
      if (r.length > 1) _tracks[w.id] = r.map((p) => p.pos).toList();
      if (!mounted) return;
    }
    setState(() => _loading = false);
  }

  List<Workout> _filtered(HealthService hs) {
    final lim = DateTime.now().subtract(Duration(days: _days));
    return hs.workouts.where((w) => w.hasRoute && w.start.isAfter(lim)).toList();
  }

  void _fit(List<LatLng> pts) {
    if (pts.length < 2) return;
    _ctrl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(48)));
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(listenable: hs, builder: (ctx, _) {
      final ws = _filtered(hs);
      if (_stamp != ws.length + _days) { _stamp = ws.length + _days; WidgetsBinding.instance.addPostFrameCallback((_) => _load(ws)); }
      final shown = [for (final w in ws) if (_tracks.containsKey(w.id)) w];
      final all = [for (final w in shown) ..._tracks[w.id]!];
      return SafeArea(child: Column(children: [
        M3PageHeader(title: L.navMap, subtitle: '${shown.length} ${isFr ? 'tracés' : 'routes'}'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          for (final d in [7, 30, 90, 3650]) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(label: Text(d == 3650 ? (isFr ? 'Tout' : 'All') : '${d}j'), selected: _days == d, onSelected: (_) => setState(() { _days = d; _sel = null; }))),
          if (_loading) const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ])),
        const SizedBox(height: 8),
        Expanded(child: shown.isEmpty && !_loading
            ? M3EmptyState(icon: Icons.map_rounded, message: isFr ? 'Aucun tracé GPS sur cette période' : 'No GPS routes in this period')
            : Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                    initialCenter: all.isNotEmpty ? all.first : const LatLng(47.5, 6.8), initialZoom: 11,
                    onMapReady: () => _fit(all)),
                children: [
                  hsTileLayer(ctx),
                  PolylineLayer(polylines: [
                    for (final w in shown) Polyline(points: _tracks[w.id]!, strokeWidth: _sel?.id == w.id ? 7 : 4,
                        color: w.sport.color.withValues(alpha: _sel == null || _sel!.id == w.id ? 0.95 : 0.35)),
                  ]),
                  const SimpleAttributionWidget(source: Text('© OpenStreetMap · CARTO')),
                ])))),
        SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), children: [
          for (final w in shown) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () { setState(() => _sel = w); _fit(_tracks[w.id]!); },
            onLongPress: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w))),
            child: Container(
              width: 150, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _sel?.id == w.id ? w.sport.color : Theme.of(ctx).colorScheme.outlineVariant, width: 2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(w.sport.icon, size: 16, color: w.sport.color), const SizedBox(width: 6),
                  Expanded(child: Text(sportName(w.sport), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)))]),
                Text(fmtDate(w.start), style: Theme.of(ctx).textTheme.labelSmall),
                Text(distLabel(w.distanceM)),
              ]),
            ))),
        ])),
      ]));
    });
  }
}
