// Extra dashboard cards: greeting, weekly goal + streak, 7-day steps, calories, "on this day", records.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import 'health_cards.dart';
import 'hs_widgets.dart';
import 'period_picker.dart' show dayOnly, fullDate, mondayOf, monthName;

String _num(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u202F');
DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Greeting + one sentence about today.
class DashGreeting extends StatelessWidget {
  final HealthService hs; final int goal; final void Function(Workout) onOpen;
  const DashGreeting({super.key, required this.hs, required this.goal, required this.onOpen});

  int _streak() {
    final days = {for (final w in hs.workouts) _d(w.start)};
    var d = _d(DateTime.now());
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) { n++; d = d.subtract(const Duration(days: 1)); }
    return n;
  }

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final h = DateTime.now().hour;
    final hello = isFr ? (h < 5 ? 'Bonne nuit' : h < 12 ? 'Bonjour' : h < 18 ? 'Bon après-midi' : 'Bonsoir')
                       : (h < 5 ? 'Good night' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening');
    final name = profileNameNotifier.value;
    final steps = hs.dayStat(DateTime.now())?.steps ?? 0;
    final left = goal - steps;
    final streak = _streak();
    final sentence = steps == 0 && hs.days.isEmpty
        ? (isFr ? 'Synchronise tes données pour commencer.' : 'Sync your data to get started.')
        : left <= 0
            ? (isFr ? 'Objectif de pas atteint aujourd\'hui, bravo.' : 'Step goal reached today, well done.')
            : (isFr ? 'Il te reste ${_num(left)} pas pour atteindre ton objectif.' : '${_num(left)} steps left to reach your goal.');
    final streakTxt = streak >= 2 ? (isFr ? ' $streak jours de suite avec une séance.' : ' $streak days in a row with a workout.') : '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 8), child: Container(
        width: double.infinity, padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [s.primaryContainer, Color.alphaBlend(s.tertiary.withValues(alpha: 0.18), s.primaryContainer)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? hello : '$hello, $name', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: s.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text('$sentence$streakTxt', style: t.bodyMedium?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.85), height: 1.35)),
          const SizedBox(height: 6),
          Text(fullDate(DateTime.now()), style: t.labelMedium?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.7))),
        ]),
      )),
    );
  }
}

/// Weekly goal: one dot per day of the week, filled when a workout was done.
class DashGoals extends StatelessWidget {
  final HealthService hs; final Color color;
  const DashGoals({super.key, required this.hs, required this.color});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final mon = mondayOf(DateTime.now());
    final today = _d(DateTime.now());
    final week = hs.workouts.where((w) => !_d(w.start).isBefore(mon) && _d(w.start).isBefore(mon.add(const Duration(days: 7)))).toList();
    final done = {for (final w in week) _d(w.start)};
    final goal = weeklyGoalNotifier.value;
    const fr = ['L', 'M', 'M', 'J', 'V', 'S', 'D'], en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return HealthCard(
      icon: Icons.flag_rounded, title: isFr ? 'Objectif de la semaine' : 'Weekly goal', color: color,
      trailing: '${week.length} / $goal ${isFr ? 'séances' : 'workouts'}',
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++) () {
            final day = mon.add(Duration(days: i));
            final on = done.contains(day), isToday = day == today;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 400 + 90 * i), curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
              child: Column(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(
                    color: on ? color : s.surfaceContainerHighest, shape: BoxShape.circle,
                    border: isToday ? Border.all(color: color, width: 2) : null),
                    child: Icon(on ? Icons.check_rounded : Icons.circle_outlined, size: on ? 20 : 8, color: on ? s.surface : s.outline)),
                const SizedBox(height: 4),
                Text((isFr ? fr : en)[i], style: t.labelSmall?.copyWith(color: isToday ? color : s.onSurfaceVariant, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500)),
              ]),
            );
          }(),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: goal > 0 ? (week.length / goal).clamp(0.0, 1.0) : 0), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: s.surfaceContainerHighest))),
      ]),
    );
  }
}

/// Steps of the last 7 days with the goal.
class DashSteps7 extends StatelessWidget {
  final HealthService hs; final Color color; final int goal; final VoidCallback onTap;
  const DashSteps7({super.key, required this.hs, required this.color, required this.goal, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final today = _d(DateTime.now());
    final data = <(DateTime, double)>[for (var i = 6; i >= 0; i--) () {
      final d = today.subtract(Duration(days: i));
      return (d, (hs.dayStat(d)?.steps ?? 0).toDouble());
    }()];
    final total = data.fold<double>(0, (a, e) => a + e.$2);
    if (total == 0) return const SizedBox.shrink();
    final best = data.reduce((a, b) => a.$2 >= b.$2 ? a : b);
    final reached = data.where((e) => e.$2 >= goal).length;
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    return HealthCard(
      icon: Icons.directions_walk_rounded, title: isFr ? 'Pas, 7 derniers jours' : 'Steps, last 7 days', color: color, onTap: onTap,
      trailing: isFr ? 'objectif atteint $reached / 7' : 'goal reached $reached / 7',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BigValue(_num(total / 7), isFr ? 'pas / jour' : 'steps / day', caption: isFr ? 'moyenne' : 'average'),
        const SizedBox(height: 10),
        MiniBars(data: data, color: color),
        const SizedBox(height: 8),
        Text(isFr ? 'Meilleur jour : ${fullDate(best.$1)} avec ${_num(best.$2)} pas.' : 'Best day: ${fullDate(best.$1)} with ${_num(best.$2)} steps.',
            style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
      ]),
    );
  }
}

/// Active calories of the last 14 days.
class DashKcal extends StatelessWidget {
  final HealthService hs; final Color color; final VoidCallback onTap;
  const DashKcal({super.key, required this.hs, required this.color, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final today = _d(DateTime.now());
    final v = [for (var i = 13; i >= 0; i--) hs.dayStat(today.subtract(Duration(days: i)))?.activeKcal ?? 0.0];
    final total = v.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    final lastWeek = v.skip(7).fold<double>(0, (a, b) => a + b), prevWeek = v.take(7).fold<double>(0, (a, b) => a + b);
    final diff = prevWeek > 0 ? ((lastWeek - prevWeek) / prevWeek * 100).round() : null;
    return HealthCard(
      icon: Icons.local_fire_department_rounded, title: isFr ? 'Calories actives, 14 jours' : 'Active calories, 14 days', color: color, onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BigValue(_num(total / 14), isFr ? 'kcal / jour' : 'kcal / day', caption: isFr ? 'moyenne' : 'average'),
        const SizedBox(height: 8),
        MiniArea(v: v, color: color),
        if (diff != null) ...[
          const SizedBox(height: 8),
          Text(isFr ? '${diff >= 0 ? '+' : ''}$diff % par rapport aux 7 jours précédents.' : '${diff >= 0 ? '+' : ''}$diff% versus the previous 7 days.',
              style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// Workouts done on the same calendar day in earlier years.
class DashOnThisDay extends StatelessWidget {
  final HealthService hs; final Color color; final void Function(Workout) onOpen;
  const DashOnThisDay({super.key, required this.hs, required this.color, required this.onOpen});
  @override
  Widget build(BuildContext c) {
    final n = DateTime.now();
    final hits = hs.workouts.where((w) => w.start.month == n.month && w.start.day == n.day && w.start.year < n.year).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    if (hits.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    return HealthCard(
      icon: Icons.history_toggle_off_rounded, title: isFr ? 'Jour pour jour' : 'On this day', color: color,
      trailing: '${n.day} ${monthName(n.month)}',
      child: Column(children: [
        for (final w in hits.take(4)) InkWell(
          borderRadius: BorderRadius.circular(12), onTap: () => onOpen(w),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
            Icon(w.sport.icon, size: 22, color: color), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isFr ? 'Il y a ${n.year - w.start.year} an${n.year - w.start.year > 1 ? 's' : ''} · ${sportName(w.sport)}'
                        : '${n.year - w.start.year} year${n.year - w.start.year > 1 ? 's' : ''} ago · ${sportName(w.sport)}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${fmtDuration(w.duration)}${w.distanceM > 100 ? ' · ${distLabel(w.distanceM)}' : ''}${w.kcal > 0 ? ' · ${w.kcal.round()} kcal' : ''}',
                  style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded, size: 18, color: s.onSurfaceVariant),
          ])),
        ),
      ]),
    );
  }
}

/// Personal records.
class DashRecords extends StatelessWidget {
  final HealthService hs; final Color color; final void Function(Workout) onOpen;
  const DashRecords({super.key, required this.hs, required this.color, required this.onOpen});
  @override
  Widget build(BuildContext c) {
    final ws = hs.workouts;
    if (ws.length < 3) return const SizedBox.shrink();
    Workout? best(double Function(Workout) f, {bool Function(Workout)? where}) {
      Workout? b; var bv = 0.0;
      for (final w in ws) { if (where != null && !where(w)) continue; final v = f(w); if (v > bv) { bv = v; b = w; } }
      return b;
    }
    final far = best((w) => w.distanceM);
    final long = best((w) => w.duration.inMinutes.toDouble());
    final burn = best((w) => w.kcal);
    Workout? fast; double fv = 1e9;
    for (final w in ws) { final p = w.paceMinKm; if (p != null && w.distanceM >= 1000 && p > 2 && p < fv) { fv = p; fast = w; } }
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    final rows = <(IconData, String, String, Workout?)>[
      if (far != null && far.distanceM > 100) (Icons.straighten_rounded, isFr ? 'Plus longue distance' : 'Longest distance', distLabel(far.distanceM), far),
      if (long != null) (Icons.timer_rounded, isFr ? 'Séance la plus longue' : 'Longest workout', fmtDuration(long.duration), long),
      if (burn != null && burn.kcal > 0) (Icons.local_fire_department_rounded, isFr ? 'Plus de calories' : 'Most calories', '${burn.kcal.round()} kcal', burn),
      if (fast != null) (Icons.speed_rounded, isFr ? 'Meilleure allure' : 'Best pace', '${fv.floor()}:${((fv - fv.floor()) * 60).round().toString().padLeft(2, '0')} min/km', fast),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return HealthCard(
      icon: Icons.emoji_events_rounded, title: isFr ? 'Records personnels' : 'Personal records', color: color,
      child: Column(children: [
        for (final r in rows) InkWell(
          borderRadius: BorderRadius.circular(12), onTap: r.$4 == null ? null : () => onOpen(r.$4!),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
            Icon(r.$1, size: 20, color: color), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.$2, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
              Text(r.$3, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ])),
            if (r.$4 != null) Text(fullDate(r.$4!.start, weekday: false), style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
          ])),
        ),
      ]),
    );
  }
}

/// Estimated "form of the day" from last night's sleep, HRV and resting heart rate versus your own 30-day average.
/// It is a personal indicator, not a medical score.
class DashReadiness extends StatelessWidget {
  final List<(DateTime, double)> sleep, hrv, rhr; final Color color;
  const DashReadiness({super.key, required this.sleep, required this.hrv, required this.rhr, required this.color});

  static double? _ratio(List<(DateTime, double)> l) {
    if (l.length < 4) return null;
    final last = l.last.$2;
    final base = l.reversed.skip(1).take(30).map((e) => e.$2).toList();
    final avg = base.fold<double>(0, (a, b) => a + b) / base.length;
    return avg <= 0 ? null : last / avg;
  }

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final parts = <(String, double, String)>[]; // label, score 0..100, detail
    if (sleep.isNotEmpty && DateTime.now().difference(sleep.last.$1).inDays <= 2) {
      final h = sleep.last.$2;
      parts.add((isFr ? 'Sommeil' : 'Sleep', (h / 8 * 100).clamp(0, 100).toDouble(), '${h.floor()} h ${((h - h.floor()) * 60).round().toString().padLeft(2, '0')}'));
    }
    final rh = _ratio(hrv);
    if (rh != null) parts.add(('HRV', (70 + (rh - 1) * 150).clamp(0, 100).toDouble(), '${rh >= 1 ? '+' : ''}${((rh - 1) * 100).round()} %'));
    final rr = _ratio(rhr);
    if (rr != null) parts.add((isFr ? 'FC repos' : 'Resting HR', (70 - (rr - 1) * 300).clamp(0, 100).toDouble(), '${rr >= 1 ? '+' : ''}${((rr - 1) * 100).round()} %'));
    if (parts.length < 2) return const SizedBox.shrink();
    final score = (parts.fold<double>(0, (a, e) => a + e.$2) / parts.length).round();
    final sentence = score >= 80
        ? (isFr ? 'Très bonne forme : tes indicateurs sont au-dessus de ton habitude.' : 'Great shape: your indicators are above your usual.')
        : score >= 60
            ? (isFr ? 'Bonne forme : tout est dans ton rythme habituel.' : 'Good shape: everything is in your usual range.')
            : score >= 40
                ? (isFr ? 'Forme moyenne : privilégie une séance légère et un bon sommeil.' : 'Average shape: favor an easy session and good sleep.')
                : (isFr ? 'Récupération incomplète : un jour de repos serait bienvenu.' : 'Incomplete recovery: a rest day would help.');
    return HealthCard(
      icon: Icons.bolt_rounded, title: isFr ? 'Forme du jour' : 'Readiness', color: color,
      trailing: isFr ? 'estimation' : 'estimate',
      child: Row(children: [
        RingProgress(value: score / 100, size: 104, center: '$score', caption: '/ 100'),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showAdviceNotifier.value) Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text(sentence, style: t.bodyMedium?.copyWith(height: 1.3))),
          for (final p in parts) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Expanded(child: Text(p.$1, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant))),
            Text(p.$3, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
          ])),
        ])),
      ]),
    );
  }
}
