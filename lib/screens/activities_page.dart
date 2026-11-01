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
        final types = {for (final w in hs.workouts) w.type};
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(isFr ? 'Tout' : 'All'), selected: _type == null, onSelected: (_) => setState(() => _type = null))),
            for (final t in types) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(avatar: Icon(sportOf(t).icon, size: 16), label: Text(sportName(sportOf(t))),
                    selected: _type == t, onSelected: (_) => setState(() => _type = t))),
          ])),
          if (srcs.length > 1) SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(avatar: const Icon(Icons.apps_rounded, size: 16),
                label: Text(isFr ? 'Toutes les applis' : 'All apps'), selected: _src == null, onSelected: (_) => setState(() => _src = null))),
            for (final a in srcs) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(a), selected: _src == a, onSelected: (_) => setState(() => _src = a))),
          ])),
          Expanded(child: list.isEmpty
              ? (hs.loading
                  ? Center(child: SyncLoader(text: hs.stage.isEmpty ? (isFr ? 'Chargement…' : 'Loading…') : hs.stage, progress: hs.progress))
                  : M3EmptyState(icon: Icons.fitness_center_rounded, message: isFr ? 'Aucune activité' : 'No activities'))
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
