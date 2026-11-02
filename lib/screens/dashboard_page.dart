// Dashboard: profile header, today, last workout, strength, week, recent.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart' show M3CookieBadge;
import '../widgets/skeleton.dart' show M3LoadingIndicator;
import 'settings_page.dart' show SettingsPage;
import 'workout_detail_page.dart';

class DashboardPage extends StatelessWidget {
  final void Function(int) onOpenTab;
  const DashboardPage({super.key, required this.onOpenTab});

  static DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([hs, profileNameNotifier, stepGoalNotifier, weeklyGoalNotifier, unitsMetricNotifier, localeNotifier, sportColorsNotifier]),
      builder: (ctx, _) {
        final s = Theme.of(ctx).colorScheme, t = Theme.of(ctx).textTheme;
        final today = hs.dayStat(DateTime.now());
        final goal = stepGoalNotifier.value;
        final mon = _monday(DateTime.now());
        final week = hs.between(mon, mon.add(const Duration(days: 7)));
        final last = hs.last;
        final strength = hs.lastOf((w) => w.sport.strength);
        void open(Workout w) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w)));

        return RefreshIndicator(
          onRefresh: () => hs.sync(),
          child: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true, expandedHeight: 170, backgroundColor: s.surface,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [s.primary.withValues(alpha: 0.35), s.surface])),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(ctx).padding.top + 16, 20, 16),
                  alignment: Alignment.bottomLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const Scaffold(body: SettingsPage(pushed: true)))),
                    child: Row(children: [
                      M3CookieBadge(color: s.primary, size: 62,
                          child: Text(profileNameNotifier.value.isEmpty ? '?' : profileNameNotifier.value[0].toUpperCase(),
                              style: t.headlineSmall?.copyWith(color: s.onPrimary, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profileNameNotifier.value.isEmpty ? (isFr ? 'Configurer le profil' : 'Set up profile') : profileNameNotifier.value,
                            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text(_sub(hs), style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                      ])),
                      if (hs.loading) const M3LoadingIndicator(size: 32),
                    ]),
                  ),
                ),
              ),
            ),
            SliverList(delegate: SliverChildListDelegate([
              if (!hs.permitted) _ConnectCard(hs: hs),
              if (hs.permitted && !hs.hasHistoryPerm) _HistoryCard(hs: hs),
              if (hs.error != null) Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Expanded(child: Text(hs.error!, style: TextStyle(color: s.error))),
                TextButton(onPressed: hs.loading ? null : () => hs.sync(), child: Text(isFr ? 'Réessayer' : 'Retry')),
              ])),
              if (hs.loading && hs.workouts.isEmpty)
                Center(child: SyncLoader(text: hs.stage.isEmpty ? (isFr ? 'Chargement…' : 'Loading…') : hs.stage, progress: hs.progress)),

              SectionTitle(isFr ? 'Aujourd\'hui' : 'Today'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
                RingProgress(value: goal > 0 ? (today?.steps ?? 0) / goal : 0,
                    center: '${today?.steps ?? 0}', caption: '/ $goal ${isFr ? 'pas' : 'steps'}'),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  StatTile(icon: Icons.local_fire_department_rounded, value: '${(today?.activeKcal ?? 0).round()}', label: 'kcal'),
                  const SizedBox(height: 10),
                  StatTile(icon: Icons.straighten_rounded, value: distLabel(today?.distanceM ?? 0), label: isFr ? 'Distance' : 'Distance'),
                ])),
              ])),

              SectionTitle(isFr ? 'Dernière séance' : 'Last workout'),
              if (last == null) Padding(padding: const EdgeInsets.all(20), child: Text(isFr ? 'Aucune séance synchronisée.' : 'No workout synced yet.'))
              else WorkoutCard(w: last, onTap: () => open(last)),

              if (strength != null) ...[
                SectionTitle(isFr ? 'Dernière séance de muscu' : 'Last strength session'),
                WorkoutCard(w: strength, onTap: () => open(strength)),
              ],

              SectionTitle(isFr ? 'Cette semaine' : 'This week'),
              StatGrid([
                StatTile(icon: Icons.event_available_rounded, value: '${week.length}/${weeklyGoalNotifier.value}', label: isFr ? 'Séances' : 'Workouts'),
                StatTile(icon: Icons.timer_rounded, value: fmtDuration(week.fold(Duration.zero, (a, w) => a + w.duration)), label: isFr ? 'Durée' : 'Duration'),
                StatTile(icon: Icons.route_rounded, value: distLabel(week.fold(0.0, (a, w) => a + w.distanceM)), label: 'Distance'),
                StatTile(icon: Icons.local_fire_department_rounded, value: '${week.fold(0.0, (a, w) => a + w.kcal).round()}', label: 'kcal'),
              ]),

              SectionTitle(isFr ? 'Récent' : 'Recent', trailing: TextButton(onPressed: () => onOpenTab(1), child: Text(isFr ? 'Tout voir' : 'See all'))),
              for (final w in hs.workouts.skip(1).take(5)) WorkoutCard(w: w, onTap: () => open(w)),
              const SizedBox(height: 32),
            ])),
          ]),
        );
      },
    );
  }

  String _sub(HealthService hs) {
    if (hs.lastSync == null) return isFr ? 'Non synchronisé' : 'Not synced';
    final m = DateTime.now().difference(hs.lastSync!).inMinutes;
    return isFr ? 'Synchronisé il y a ${m < 1 ? "<1" : m} min' : 'Synced ${m < 1 ? "<1" : m} min ago';
  }
}

class _HistoryCard extends StatelessWidget {
  final HealthService hs;
  const _HistoryCard({required this.hs});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: s.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.history_rounded, color: s.tertiary),
        const SizedBox(width: 12),
        Expanded(child: Text(isFr ? 'Sans l\'accès à l\'historique, seuls les 30 derniers jours sont lus.' : 'Without history access only the last 30 days are read.',
            style: TextStyle(color: s.onTertiaryContainer))),
        FilledButton(onPressed: hs.requestPermissions, child: Text(isFr ? 'Autoriser' : 'Allow')),
      ]),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  final HealthService hs;
  const _ConnectCard({required this.hs});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.favorite_rounded, color: s.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(isFr ? 'Connectez Health Connect pour voir vos données.' : 'Connect Health Connect to see your data.',
            style: TextStyle(color: s.onPrimaryContainer))),
        FilledButton(onPressed: hs.requestPermissions, child: Text(isFr ? 'Connecter' : 'Connect')),
      ]),
    );
  }
}
