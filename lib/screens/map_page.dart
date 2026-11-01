// Map tab: all GPS routes (whole history) on one map.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_state.dart';
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
  int _days = 3650; // all history by default
  Workout? _sel;
  int _stamp = -1;
  int _fitted = -1;

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
    return ListenableBuilder(
      listenable: Listenable.merge([hs, sportColorsNotifier, localeNotifier]),
      builder: (ctx, _) {
        final ws = _filtered(hs);
        // Load missing tracks when the list or the period changes
        if (_stamp != ws.length + _days) {
          _stamp = ws.length + _days;
          WidgetsBinding.instance.addPostFrameCallback((_) => hs.loadTracks(ws));
        }
        final shown = [for (final w in ws) if (hs.tracks.containsKey(w.id)) w];
        final all = [for (final w in shown) ...hs.tracks[w.id]!];
        // Zoom on everything once the first tracks are there
        if (all.length > 1 && _fitted != shown.length && !hs.trackBusy) {
          _fitted = shown.length;
          WidgetsBinding.instance.addPostFrameCallback((_) { try { _fit(all); } catch (_) {} });
        }
        final loading = hs.trackBusy || (hs.loading && ws.isEmpty);
        return SafeArea(child: Column(children: [
          M3PageHeader(showBack: false, title: L.navMap, subtitle: '${shown.length} ${isFr ? 'tracés' : 'routes'}'),
          SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final d in [7, 30, 90, 365, 3650]) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(d == 3650 ? (isFr ? 'Tout' : 'All') : d == 365 ? (isFr ? '1 an' : '1y') : '${d}j'),
                    selected: _days == d, onSelected: (_) => setState(() { _days = d; _sel = null; _fitted = -1; }))),
          ])),
          if (hs.trackBusy) Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 4), child: M3WavyProgress(value: hs.trackProgress, height: 10)),
          const SizedBox(height: 4),
          Expanded(child: shown.isEmpty
              ? Center(child: loading
                  ? SyncLoader(text: isFr ? 'Chargement des tracés…' : 'Loading routes…', progress: hs.trackBusy ? hs.trackProgress : null)
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      M3EmptyState(icon: Icons.map_rounded, message: ws.isEmpty
                          ? (isFr ? 'Aucun tracé GPS sur cette période' : 'No GPS routes in this period')
                          : (isFr ? 'Les tracés doivent être autorisés' : 'Routes need your permission')),
                      if (ws.isNotEmpty) FilledButton.icon(
                          onPressed: () => hs.loadTracks(ws, ask: true),
                          icon: const Icon(Icons.route_rounded),
                          label: Text(isFr ? 'Autoriser et charger les tracés' : 'Allow and load routes')),
                    ]))
              : Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: FlutterMap(
                  mapController: _ctrl,
                  options: MapOptions(
                      initialCenter: all.isNotEmpty ? all.first : const LatLng(47.5, 6.8), initialZoom: 11,
                      onMapReady: () => _fit(all)),
                  children: [
                    hsTileLayer(ctx),
                    PolylineLayer(polylines: [
                      for (final w in shown) Polyline(points: hs.tracks[w.id]!, strokeWidth: _sel?.id == w.id ? 7 : 4,
                          color: sportColor(ctx, w.sport).withValues(alpha: _sel == null || _sel!.id == w.id ? 0.95 : 0.35)),
                    ]),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                  ])))),
          SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), children: [
            for (final w in shown) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
              onTap: () { setState(() => _sel = w); _fit(hs.tracks[w.id]!); },
              onLongPress: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w))),
              child: Container(
                width: 150, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _sel?.id == w.id ? sportColor(ctx, w.sport) : Theme.of(ctx).colorScheme.outlineVariant, width: 2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(w.sport.icon, size: 16, color: sportColor(ctx, w.sport)), const SizedBox(width: 6),
                    Expanded(child: Text(sportName(w.sport), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)))]),
                  Text(fmtDate(w.start), style: Theme.of(ctx).textTheme.labelSmall),
                  Text(distLabel(w.distanceM)),
                ]),
              ))),
          ])),
        ]));
      },
    );
  }
}
