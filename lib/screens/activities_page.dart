// Activities tab: workout list filterable by sport.
import 'package:flutter/material.dart';
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
  int? _type; // null = tout

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(listenable: hs, builder: (ctx, _) {
      final types = {for (final w in hs.workouts) w.type};
      final list = hs.workouts.where((w) => _type == null || w.type == _type).toList();
      return SafeArea(child: Column(children: [
        M3PageHeader(title: L.navActivities, subtitle: '${list.length}'),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(isFr ? 'Tout' : 'All'), selected: _type == null, onSelected: (_) => setState(() => _type = null))),
          for (final t in types) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(avatar: Icon(sportOf(t).icon, size: 16), label: Text(sportName(sportOf(t))),
                  selected: _type == t, onSelected: (_) => setState(() => _type = t))),
        ])),
        Expanded(child: list.isEmpty
            ? M3EmptyState(icon: Icons.fitness_center_rounded, message: isFr ? 'Aucune activité' : 'No activities')
            : RefreshIndicator(onRefresh: () => hs.sync(), child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24), itemCount: list.length,
                itemBuilder: (_, i) => WorkoutCard(w: list[i], onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: list[i]))))))),
      ]));
    });
  }
}
