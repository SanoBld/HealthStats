// Dashboard in the style of Apple Health / Android Health: summary cards you can open.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart' show M3CookieBadge, M3WavyProgress;
import '../widgets/scroll_status_bar.dart';
import 'metric_page.dart';
import 'settings_page.dart' show SettingsPage;
import 'sleep_detail_page.dart';
import 'workout_detail_page.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int) onOpenTab;
  const DashboardPage({super.key, required this.onOpenTab});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<(DateTime, double)> _sleep = [], _rhr = [], _hrv = [], _spo2 = [], _weight = [];
  ({DateTime start, DateTime end, int minutes})? _night;
  int _loadedFor = -1;

  @override
  void initState() { super.initState(); HealthService.instance.addListener(_onHs); _load(); }
  @override
  void dispose() { HealthService.instance.removeListener(_onHs); super.dispose(); }
  void _onHs() {
    final k = HealthService.instance.lastSync?.millisecondsSinceEpoch ?? 0;
    if (k != _loadedFor) _load();
  }

  Future<void> _load() async {
    final hs = HealthService.instance;
    if (!hs.permitted) return;
    _loadedFor = hs.lastSync?.millisecondsSinceEpoch ?? 0;
    final f = [hs.sleepNights(), hs.metric('restingHr'), hs.metric('hrv'), hs.metric('spo2'), hs.weights()];
    final night = hs.lastSleep();
    final r = await Future.wait(f);
    final n = await night;
    if (!mounted) return;
    setState(() { _sleep = r[0]; _rhr = r[1]; _hrv = r[2]; _spo2 = r[3]; _weight = r[4]; _night = n; });
  }

  void _push(Widget p) => Navigator.push(context, MaterialPageRoute(builder: (_) => p));
  String _hm(int min) => '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext ctx) {
    final hs = HealthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([hs, profileNameNotifier, stepGoalNotifier, weeklyGoalNotifier, unitsMetricNotifier, localeNotifier, sportColorsNotifier]),
      builder: (ctx, _) {
        final s = Theme.of(ctx).colorScheme, t = Theme.of(ctx).textTheme;
        final today = hs.dayStat(DateTime.now());
        final goal = stepGoalNotifier.value;
        final mon = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        final week = hs.between(DateTime(mon.year, mon.month, mon.day), DateTime(mon.year, mon.month, mon.day).add(const Duration(days: 7)));
        void open(Workout w) => _push(WorkoutDetailPage(workout: w));
        Color col(Color c) => sportColorsNotifier.value ? c : s.primary;
        final fire = col(const Color(0xFFFF5A3C)),
              blue = col(const Color(0xFF3D8BFF)),
              violet = col(const Color(0xFF7C5CFF)),
              red = col(const Color(0xFFFF2D55)),
              green = col(const Color(0xFF34C759));

        List<(DateTime, double)> daily(double Function(DayStat) f) => [for (final d in hs.days) (d.day, f(d))];

        return ScrollStatusBarHost(
          color: s.surface,
          threshold: 0,
          child: RefreshIndicator(
            onRefresh: () async { await hs.sync(); await _load(); },
            child: ListView(padding: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 8, bottom: 32), children: [
            if (hs.loading) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 4), child: M3WavyProgress(value: hs.progress ?? 0, height: 10)),
            // ── profile header ──
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _push(const Scaffold(body: SettingsPage(pushed: true))),
              child: Row(children: [
                M3CookieBadge(color: s.primary, size: 52,
                    child: Text(profileNameNotifier.value.isEmpty ? '?' : profileNameNotifier.value[0].toUpperCase(),
                        style: t.titleLarge?.copyWith(color: s.onPrimary, fontWeight: FontWeight.w800))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profileNameNotifier.value.isEmpty ? (isFr ? 'Configurer le profil' : 'Set up profile') : profileNameNotifier.value,
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(_sub(hs), style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                ])),
              ]),
            )),
            if (!hs.permitted) _ConnectCard(hs: hs),
            if (hs.permitted && !hs.hasHistoryPerm) _HistoryCard(hs: hs),
            if (hs.error != null) Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Expanded(child: Text(hs.error!, style: TextStyle(color: s.error))),
              TextButton(onPressed: hs.loading ? null : () => hs.sync(), child: Text(isFr ? 'Réessayer' : 'Retry')),
            ])),
            if (hs.loading && hs.workouts.isEmpty)
              Center(child: SyncLoader(text: hs.stage.isEmpty ? (isFr ? 'Chargement…' : 'Loading…') : hs.stage, progress: hs.progress)),

            SectionTitle(isFr ? 'Résumé' : 'Summary', compact: true),
            // ── today: tap = day / week / month / year ──
            HealthCard(
              icon: Icons.directions_walk_rounded, title: isFr ? 'Aujourd\'hui' : 'Today', color: fire,
              onTap: () => _push(MetricPage(title: isFr ? 'Pas' : 'Steps', unit: isFr ? 'pas' : 'steps', icon: Icons.directions_walk_rounded, color: fire,
                  series: daily((d) => d.steps.toDouble()), fmt: (v) => v.round().toString(),
                  desc: isFr ? 'Nombre de pas faits chaque jour. L\'objectif se règle dans les réglages.' : 'Steps taken each day. Set your goal in settings.',
                  verdict: (v, fr) => v >= goal
                      ? (fr ? 'Bien : ta moyenne des 7 derniers jours atteint ton objectif.' : 'Good: your 7-day average reaches your goal.')
                      : v >= goal * 0.6
                          ? (fr ? 'Correct : tu es proche de ton objectif, encore un petit effort.' : 'OK: close to your goal, a small push left.')
                          : (fr ? 'Faible : ta moyenne des 7 derniers jours est loin de ton objectif.' : 'Low: your 7-day average is far from your goal.'))),
              child: Row(children: [
                RingProgress(value: goal > 0 ? (today?.steps ?? 0) / goal : 0, size: 112,
                    center: '${today?.steps ?? 0}', caption: '/ $goal ${isFr ? 'pas' : 'steps'}'),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  _Line(icon: Icons.local_fire_department_rounded, color: fire, value: '${(today?.activeKcal ?? 0).round()}', unit: 'kcal',
                      onTap: () => _push(MetricPage(title: isFr ? 'Calories actives' : 'Active calories', unit: 'kcal', icon: Icons.local_fire_department_rounded, color: fire,
                          series: daily((d) => d.activeKcal), fmt: (v) => v.round().toString()))),
                  const SizedBox(height: 8),
                  _Line(icon: Icons.straighten_rounded, color: blue, value: distLabel(today?.distanceM ?? 0), unit: '',
                      onTap: () => _push(MetricPage(title: 'Distance', unit: unitsMetricNotifier.value ? 'km' : 'mi', icon: Icons.straighten_rounded, color: blue,
                          series: daily((d) => d.distanceM), fmt: (v) => unitsMetricNotifier.value ? (v / 1000).toStringAsFixed(1) : (v / 1609.344).toStringAsFixed(1)))),
                ])),
              ]),
            ),

            // ── sleep ──
            if (_night != null || _sleep.isNotEmpty) HealthCard(
              icon: Icons.bedtime_rounded, title: isFr ? 'Sommeil' : 'Sleep', color: violet,
              trailing: _night == null ? null : fmtDay(_night!.end),
              onTap: _sleep.isEmpty ? null : () => _push(SleepDetailPage(nights: _sleep)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_night != null) ...[
                  BigValue(_hm(_night!.minutes), '', caption: isFr ? 'dernière nuit' : 'last night'),
                  const SizedBox(height: 4),
                  // Sleep quality summary
                  Text(
                    _night!.minutes >= 420 && _night!.minutes <= 540
                        ? (isFr ? 'Bon sommeil' : 'Good sleep')
                        : _night!.minutes >= 360
                            ? (isFr ? 'Insuffisant' : 'Insufficient')
                            : (isFr ? 'Trop court' : 'Too short'),
                    style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SleepSpan(start: _night!.start, end: _night!.end, color: violet),
                ],
                if (_sleep.length > 1) ...[
                  const SizedBox(height: 16),
                  MiniBars(data: _sleep.reversed.take(7).toList().reversed.toList(), color: violet),
                ],
              ]),
            ),

            // ── heart ──
            if (_rhr.isNotEmpty || hs.days.any((d) => d.hrAvg > 0)) Builder(builder: (_) {
              final series = _rhr.isNotEmpty ? _rhr : [for (final d in hs.days) if (d.hrAvg > 0) (d.day, d.hrAvg)];
              final last = series.last.$2;
              return HealthCard(
                icon: Icons.favorite_rounded, title: isFr ? 'Fréquence cardiaque' : 'Heart rate', color: red,
                trailing: _rhr.isNotEmpty ? (isFr ? 'au repos' : 'resting') : (isFr ? 'moyenne' : 'average'),
                onTap: () => _push(MetricPage(title: isFr ? 'Fréquence cardiaque' : 'Heart rate', unit: 'bpm', icon: Icons.favorite_rounded, color: red,
                    series: series, average: true, fmt: (v) => v.round().toString(),
                    desc: isFr ? 'Nombre de battements du cœur par minute. Au repos, une valeur basse indique en général une bonne forme.' : 'Heartbeats per minute. At rest, a low value usually means good fitness.',
                    verdict: (avg, fr) {
                      final rest = _rhr.isNotEmpty;
                      if (rest) {
                        if (avg < 50) return fr ? 'Très bien : fréquence au repos très basse, signe d\'une excellente condition physique.' : 'Great: very low resting rate, a sign of excellent fitness.';
                        if (avg <= 70) return fr ? 'Bien : fréquence au repos dans la norme (60 à 100 bpm), plutôt bonne.' : 'Good: resting rate is normal (60 to 100 bpm), on the good side.';
                        if (avg <= 100) return fr ? 'Correct : dans la norme mais un peu haute. Sommeil, stress et sport peuvent la faire baisser.' : 'OK: within normal range but a bit high. Sleep, stress and exercise can lower it.';
                        return fr ? 'Élevée : au-dessus de 100 bpm au repos. Si ça dure, parle-en à un médecin.' : 'High: above 100 bpm at rest. If it lasts, talk to a doctor.';
                      }
                      if (avg < 100) return fr ? 'Bien : ta fréquence moyenne sur la journée reste raisonnable.' : 'Good: your daily average rate is reasonable.';
                      return fr ? 'Élevée : moyenne haute, probablement due à l\'activité. Regarde la fréquence au repos.' : 'High: high average, probably from activity. Check your resting rate.';
                    })),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BigValue(last.round().toString(), 'bpm', caption: fmtDay(series.last.$1)),
                  const SizedBox(height: 8),
                  MiniArea(v: [for (final e in series.reversed.take(30).toList().reversed) e.$2], color: red),
                ]),
              );
            }),

            // ── other vitals (2 per row) ──
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 12, runSpacing: 12, children: [
              for (final m in [
                ('HRV', 'ms', Icons.monitor_heart_rounded, green, _hrv, 0),
                ('SpO₂', '%', Icons.air_rounded, blue, _spo2, 0),
                (isFr ? 'Poids' : 'Weight', 'kg', Icons.monitor_weight_rounded, violet, _weight, 1),
              ]) if (m.$5.length > 1) SizedBox(
                width: (MediaQuery.of(ctx).size.width - 44) / 2,
                child: _MiniTile(title: m.$1, unit: m.$2, icon: m.$3, color: m.$4, data: m.$5, dec: m.$6,
                    onTap: () => _push(MetricPage(title: m.$1, unit: m.$2, icon: m.$3, color: m.$4, series: m.$5, average: true,
                        fmt: (v) => v.toStringAsFixed(m.$6), desc: _metricDesc(m.$1), verdict: _metricVerdict(m.$1)))),
              ),
            ])),

            // ── activities ──
            SectionTitle(isFr ? 'Dernières activités' : 'Latest activities',
                trailing: TextButton(onPressed: () => widget.onOpenTab(1), child: Text(isFr ? 'Tout voir' : 'See all'))),
            if (hs.workouts.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(isFr ? 'Aucune séance synchronisée.' : 'No workout synced yet.'))
            else for (final w in hs.workouts.take(4)) WorkoutCard(w: w, onTap: () => open(w)),

            SectionTitle(isFr ? 'Cette semaine' : 'This week'),
            StatGrid([
              StatTile(icon: Icons.event_available_rounded, value: '${week.length}/${weeklyGoalNotifier.value}', label: isFr ? 'Séances' : 'Workouts'),
              StatTile(icon: Icons.timer_rounded, value: fmtDuration(week.fold(Duration.zero, (a, w) => a + w.duration)), label: isFr ? 'Durée' : 'Duration'),
              StatTile(icon: Icons.route_rounded, value: distLabel(week.fold(0.0, (a, w) => a + w.distanceM)), label: 'Distance'),
              StatTile(icon: Icons.local_fire_department_rounded, value: '${week.fold(0.0, (a, w) => a + w.kcal).round()}', label: 'kcal'),
            ]),
          ]),
        ));
      },
    );
  }

  String _sub(HealthService hs) {
    if (hs.lastSync == null) return isFr ? 'Non synchronisé' : 'Not synced';
    final m = DateTime.now().difference(hs.lastSync!).inMinutes;
    return isFr ? 'Synchronisé il y a ${m < 1 ? "<1" : m} min' : 'Synced ${m < 1 ? "<1" : m} min ago';
  }
}

class _Line extends StatelessWidget {
  final IconData icon; final Color color; final String value, unit; final VoidCallback onTap;
  const _Line({required this.icon, required this.color, required this.value, required this.unit, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Material(
      color: s.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: color), const SizedBox(width: 8),
          Expanded(child: Text('$value${unit.isEmpty ? '' : ' $unit'}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          Icon(Icons.chevron_right_rounded, size: 18, color: s.onSurfaceVariant),
        ]))));
  }
}

class _MiniTile extends StatelessWidget {
  final String title, unit; final IconData icon; final Color color; final List<(DateTime, double)> data; final int dec; final VoidCallback onTap;
  const _MiniTile({required this.title, required this.unit, required this.icon, required this.color, required this.data, required this.dec, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.10), s.surfaceContainer),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: s.outlineVariant.withValues(alpha: 0.55), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 6),
          Expanded(child: Text(title, style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 6),
        BigValue(data.last.$2.toStringAsFixed(dec), unit),
        const SizedBox(height: 6),
        MiniArea(v: [for (final e in data.reversed.take(30).toList().reversed) e.$2], color: color, height: 44),
      ]))));
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
      decoration: BoxDecoration(color: s.tertiaryContainer, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Icon(Icons.history_rounded, color: s.tertiary), const SizedBox(width: 12),
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
      decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Icon(Icons.favorite_rounded, color: s.primary), const SizedBox(width: 12),
        Expanded(child: Text(isFr ? 'Connectez Health Connect pour voir vos données.' : 'Connect Health Connect to see your data.',
            style: TextStyle(color: s.onPrimaryContainer))),
        FilledButton(onPressed: hs.requestPermissions, child: Text(isFr ? 'Connecter' : 'Connect')),
      ]),
    );
  }
}


// Short description of a vital sign.
String _metricDesc(String k) => switch (k) {
      'HRV' => isFr ? 'Variation du temps entre deux battements. Plus elle est haute, mieux ton corps récupère et gère le stress.' : 'Variation in time between heartbeats. Higher usually means better recovery and stress handling.',
      'SpO₂' => isFr ? 'Taux d\'oxygène dans le sang. Une valeur normale est de 95 à 100 %.' : 'Oxygen level in your blood. Normal is 95 to 100%.',
      _ => isFr ? 'Ton poids au fil du temps. Regarde la tendance plutôt qu\'une seule mesure.' : 'Your weight over time. Look at the trend rather than a single reading.',
    };

// Sentence about the current state of a vital sign.
String Function(double, bool)? _metricVerdict(String k) => switch (k) {
      'HRV' => (v, fr) => v >= 50
          ? (fr ? 'Bien : ta HRV est bonne, signe d\'une bonne récupération.' : 'Good: your HRV is good, a sign of good recovery.')
          : v >= 30
              ? (fr ? 'Correct : HRV moyenne. Sommeil et repos peuvent l\'améliorer.' : 'OK: average HRV. Sleep and rest can improve it.')
              : (fr ? 'Faible : HRV basse, ton corps est peut-être fatigué ou stressé.' : 'Low: low HRV, your body may be tired or stressed.'),
      'SpO₂' => (v, fr) => v >= 95
          ? (fr ? 'Bien : ton taux d\'oxygène est normal.' : 'Good: your oxygen level is normal.')
          : v >= 90
              ? (fr ? 'Un peu bas : en dessous de 95 %. Si ça se répète, demande un avis médical.' : 'A bit low: under 95%. If it repeats, ask a doctor.')
              : (fr ? 'Bas : en dessous de 90 %. Consulte un médecin.' : 'Low: under 90%. See a doctor.'),
      _ => (v, fr) {
          final h = profileHeightNotifier.value / 100;
          if (h <= 0) return fr ? 'Renseigne ta taille dans le profil pour voir ton IMC.' : 'Add your height in the profile to see your BMI.';
          final b = v / (h * h);
          final bs = b.toStringAsFixed(1);
          if (b < 18.5) return fr ? 'IMC $bs : en dessous de la norme (18,5 à 25).' : 'BMI $bs: below the normal range (18.5 to 25).';
          if (b < 25) return fr ? 'Bien : IMC $bs, dans la norme (18,5 à 25).' : 'Good: BMI $bs, in the normal range (18.5 to 25).';
          if (b < 30) return fr ? 'IMC $bs : surpoids léger (25 à 30).' : 'BMI $bs: slightly above normal (25 to 30).';
          return fr ? 'IMC $bs : au-dessus de 30.' : 'BMI $bs: above 30.';
        },
    };
