// Activities tab: ALL workouts, filter by sport and by source app, grouped by month.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import 'workout_detail_page.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});
  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  int? _type; // null = all sports
  String? _src; // null = all apps

  String _month(DateTime d) {
    const fr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${(isFr ? fr : en)[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([hs, sportColorsNotifier, localeNotifier]),
      builder: (ctx, _) {
        final srcs = {for (final w in hs.workouts) w.sourceName};
        final list = hs.workouts.where((w) => (_type == null || w.type == _type) && (_src == null || w.sourceName == _src)).toList();
        // Items = month headers (String) + workouts
        final items = <Object>[];
        String? cur;
        for (final w in list) {
          final m = _month(w.start);
          if (m != cur) { cur = m; items.add(m); }
          items.add(w);
        }
        return SafeArea(child: Column(children: [
          M3PageHeader(showBack: false, title: L.navActivities,
              subtitle: _type == null && _src == null ? '${list.length}' : '${list.length} / ${hs.workouts.length}'),
          SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            FilterChipButton(
              label: _type == null ? (isFr ? 'Tous les sports' : 'All sports') : sportName(sportOf(_type!)),
              active: _type != null,
              onTap: () async {
                final counts = <int, int>{};
                for (final w in hs.workouts) { counts[w.type] = (counts[w.type] ?? 0) + 1; }
                final sorted = counts.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
                final r = await pickFilter(ctx, title: isFr ? 'Sport' : 'Sport', allLabel: isFr ? 'Tous les sports' : 'All sports',
                    entries: [for (final e in sorted) FilterEntry('${e.key}', sportName(sportOf(e.key)), e.value, sportOf(e.key).icon)],
                    current: _type?.toString());
                if (r != null) setState(() => _type = r.isEmpty ? null : int.parse(r));
              },
            ),
            if (srcs.length > 1) FilterChipButton(
              label: _src ?? (isFr ? 'Toutes les applis' : 'All apps'),
              active: _src != null,
              onTap: () async {
                final counts = <String, int>{};
                for (final w in hs.workouts) { counts[w.sourceName] = (counts[w.sourceName] ?? 0) + 1; }
                final sorted = counts.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
                final r = await pickFilter(ctx, title: isFr ? 'Application' : 'App', allLabel: isFr ? 'Toutes les applis' : 'All apps',
                    entries: [for (final e in sorted) FilterEntry(e.key, e.key, e.value, null, AppIcon(hs.workouts.firstWhere((w) => w.sourceName == e.key).source, size: 28))], current: _src);
                if (r != null) setState(() => _src = r.isEmpty ? null : r);
              },
            ),
          ])),
          Expanded(child: list.isEmpty
              ? (hs.loading
                  ? Center(child: SyncLoader(text: hs.stage.isEmpty ? (isFr ? 'Chargement…' : 'Loading…') : hs.stage, progress: hs.progress))
                  : M3EmptyState(icon: Icons.fitness_center_rounded, message: isFr ? 'Aucune donnée' : 'No data'))
              : RefreshIndicator(onRefresh: () => hs.sync(), child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24), itemCount: items.length,
                  itemBuilder: (_, i) {
                    final it = items[i];
                    if (it is String) return SectionTitle(it);
                    final w = it as Workout;
                    return WorkoutCard(w: w, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w))));
                  }))),
        ]));
      },
    );
  }
}
