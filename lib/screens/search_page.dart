// Search tab: sports, apps, activities and places (map location).
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3LoadingIndicator;
import 'workout_detail_page.dart';

class _Place {
  final String name; final LatLng pos;
  _Place(this.name, this.pos);
}

String _n(String s) {
  const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ', to = 'aaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

void _openList(BuildContext c, String title, List<Workout> ws) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => WorkoutListPage(title: title, workouts: ws)));

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';
  Timer? _deb;
  List<_Place> _places = [];
  bool _placeBusy = false;

  @override
  void dispose() { _deb?.cancel(); super.dispose(); }

  void _changed(String v) {
    setState(() => _q = v.trim());
    _deb?.cancel();
    if (_q.length < 3) { setState(() { _places = []; _placeBusy = false; }); return; }
    _deb = Timer(const Duration(milliseconds: 700), _geocode);
  }

  // Place search with OpenStreetMap Nominatim (no key needed)
  Future<void> _geocode() async {
    final q = _q;
    setState(() => _placeBusy = true);
    var out = <_Place>[];
    try {
      final r = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'jsonv2', 'limit': '5', 'accept-language': isFr ? 'fr' : 'en'}),
        headers: {'User-Agent': 'HealthStats/1.0 (com.healthstats.app)'}).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body) as List;
      out = [for (final e in j) _Place(e['display_name'] as String, LatLng(double.parse(e['lat'] as String), double.parse(e['lon'] as String)))];
    } catch (_) {}
    if (!mounted || q != _q) return;
    setState(() { _places = out; _placeBusy = false; });
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([hs, localeNotifier, sportColorsNotifier]),
      builder: (ctx, _) {
        final q = _n(_q);
        // sports present in the data
        final bySport = <int, List<Workout>>{};
        final byApp = <String, List<Workout>>{};
        for (final w in hs.workouts) {
          (bySport[w.type] ??= []).add(w);
          (byApp[w.sourceName] ??= []).add(w);
        }
        final sports = bySport.entries.where((e) => q.isEmpty || _n(sportOf(e.key).fr).contains(q) || _n(sportOf(e.key).en).contains(q)).toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        final apps = byApp.entries.where((e) => q.isEmpty || _n(e.key).contains(q)).toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        final acts = q.isEmpty ? <Workout>[] : hs.workouts.where((w) =>
            _n('${w.title} ${w.notes} ${w.sport.fr} ${w.sport.en} ${w.sourceName} ${fmtDate(w.start)} ${w.start.year}').contains(q)).take(30).toList();
        final s = Theme.of(ctx).colorScheme;

        Widget tile(Widget lead, String title, String sub, VoidCallback onTap) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: s.surfaceContainer, leading: lead, title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap));

        return SafeArea(child: Column(children: [
          M3PageHeader(showBack: false, title: isFr ? 'Recherche' : 'Search'),
          M3SearchField(hint: isFr ? 'Sport, appli, activité, lieu…' : 'Sport, app, activity, place…', onChanged: _changed),
          Expanded(child: hs.workouts.isEmpty
              ? (hs.loading ? Center(child: SyncLoader(text: hs.stage.isEmpty ? '…' : hs.stage, progress: hs.progress))
                  : M3EmptyState(icon: Icons.search_rounded, message: isFr ? 'Aucune donnée' : 'No data'))
              : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  if (sports.isNotEmpty) ...[
                    SectionTitle(isFr ? 'Sports' : 'Sports'),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: LayoutBuilder(builder: (_, c) {
                      final w = (c.maxWidth - 10) / 2;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final e in sports.take(q.isEmpty ? 8 : 30)) SizedBox(width: w, child: _SportBox(
                          sport: sportOf(e.key), color: sportColor(ctx, sportOf(e.key)), name: sportName(sportOf(e.key)),
                          ws: e.value, onTap: () => _openList(ctx, sportName(sportOf(e.key)), e.value))),
                      ]);
                    })),
                  ],
                  if (apps.isNotEmpty) ...[
                    SectionTitle(isFr ? 'Applications' : 'Apps'),
                    for (final e in apps) tile(AppIcon(e.value.first.source, size: 32), e.key,
                        '${e.value.length} ${isFr ? 'activités' : 'activities'}', () => _openList(ctx, e.key, e.value)),
                  ],
                  if (acts.isNotEmpty) ...[
                    SectionTitle(isFr ? 'Activités' : 'Activities'),
                    for (final w in acts) WorkoutCard(w: w, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w)))),
                  ],
                  if (_q.length >= 3) ...[
                    SectionTitle(isFr ? 'Lieux (carte)' : 'Places (map)', trailing: _placeBusy ? const M3LoadingIndicator(size: 24) : null),
                    for (final p in _places) tile(const Icon(Icons.place_rounded), p.name.split(',').first, p.name,
                        () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => _PlaceResultsPage(place: p)))),
                    if (!_placeBusy && _places.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(isFr ? 'Aucun lieu trouvé' : 'No place found', style: TextStyle(color: s.onSurfaceVariant))),
                  ],
                  if (q.isNotEmpty && sports.isEmpty && apps.isEmpty && acts.isEmpty && _places.isEmpty && !_placeBusy)
                    Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(isFr ? 'Aucune donnée' : 'No data'))),
                ])),
        ]));
      },
    );
  }
}

/// Activities of one sport / one app, with a per-app filter.
class WorkoutListPage extends StatefulWidget {
  final String title; final List<Workout> workouts;
  const WorkoutListPage({super.key, required this.title, required this.workouts});
  @override
  State<WorkoutListPage> createState() => _WorkoutListPageState();
}

class _WorkoutListPageState extends State<WorkoutListPage> {
  String? _app;
  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(listenable: hs, builder: (ctx, _) {
      final apps = <String, Workout>{};
      for (final w in widget.workouts) { apps.putIfAbsent(w.sourceName, () => w); }
      final list = widget.workouts.where((w) => _app == null || w.sourceName == _app).toList();
      return Scaffold(
        appBar: AppBar(title: Text('${widget.title} · ${list.length}')),
        body: Column(children: [
          if (apps.length > 1) SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: M3Chip(label: Text(isFr ? 'Toutes' : 'All'), selected: _app == null, onSelected: (_) => setState(() => _app = null))),
            for (final e in apps.entries) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: M3Chip(
                avatar: _app == e.key ? null : AppIcon(e.value.source, size: 16),
                label: Text('${e.key} · ${widget.workouts.where((w) => w.sourceName == e.key).length}'),
                selected: _app == e.key, onSelected: (_) => setState(() => _app = _app == e.key ? null : e.key))),
          ])),
          Expanded(child: list.isEmpty
              ? M3EmptyState(icon: Icons.search_off_rounded, message: isFr ? 'Aucune donnée' : 'No data')
              : ListView.builder(padding: const EdgeInsets.only(bottom: 24), itemCount: list.length,
                  itemBuilder: (_, i) => WorkoutCard(w: list[i], onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: list[i])))))),
        ]),
      );
    });
  }
}

/// Activities whose GPS route passes within 6 km of a place.
class _PlaceResultsPage extends StatefulWidget {
  final _Place place;
  const _PlaceResultsPage({required this.place});
  @override
  State<_PlaceResultsPage> createState() => _PlaceResultsPageState();
}

class _PlaceResultsPageState extends State<_PlaceResultsPage> {
  @override
  void initState() {
    super.initState();
    final hs = HealthService.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) => hs.loadTracks(hs.workouts));
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    const d = Distance();
    return ListenableBuilder(listenable: hs, builder: (ctx, _) {
      final found = [for (final w in hs.workouts)
        if (hs.tracks[w.id] != null && hs.tracks[w.id]!.any((p) => d.as(LengthUnit.Kilometer, p, widget.place.pos) <= 6)) w];
      return Scaffold(
        appBar: AppBar(title: Text(widget.place.name.split(',').first)),
        body: Column(children: [
          if (hs.trackBusy) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: M3WavyProgress(value: hs.trackProgress, height: 10)),
          Expanded(child: found.isEmpty
              ? (hs.trackBusy
                  ? Center(child: SyncLoader(text: isFr ? 'Lecture des tracés…' : 'Reading routes…', progress: hs.trackProgress))
                  : M3EmptyState(icon: Icons.place_rounded, message: isFr ? 'Aucune donnée autour de ce lieu' : 'No data around this place'))
              : ListView.builder(padding: const EdgeInsets.only(bottom: 24), itemCount: found.length,
                  itemBuilder: (_, i) => WorkoutCard(w: found[i], onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: found[i])))))),
        ]),
      );
    });
  }
}

/// Framed card for one sport: icon, name, number of activities, total time and distance.
class _SportBox extends StatelessWidget {
  final dynamic sport; final Color color; final String name; final List<Workout> ws; final VoidCallback onTap;
  const _SportBox({required this.sport, required this.color, required this.name, required this.ws, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final mins = ws.fold<int>(0, (a, w) => a + w.duration.inMinutes);
    final km = ws.fold<double>(0, (a, w) => a + w.distanceM) / 1000;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), s.surfaceContainer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Icon(sport.icon as IconData, color: color, size: 22)),
            const Spacer(),
            Text('${ws.length}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: color)),
          ]),
          const SizedBox(height: 10),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${mins ~/ 60} h ${(mins % 60).toString().padLeft(2, '0')}${km >= 0.1 ? ' · ${km.toStringAsFixed(km >= 100 ? 0 : 1)} km' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
        ])),
      ),
    );
  }
}
