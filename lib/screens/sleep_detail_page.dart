// Sleep detail page: sleep cycles (deep, light, REM, awake), trends, and summaries.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart' show M3SegmentedButton, M3CookieBadge;

class SleepDetailPage extends StatefulWidget {
  final List<(DateTime, double)> nights; // hours per night
  const SleepDetailPage({super.key, required this.nights});
  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  int _m = 1; // 0 = night, 1 = week, 2 = month
  List<_SleepNight> _details = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final hs = HealthService.instance;
    try {
      final raw = await hs.sleepSessions();
      if (!mounted) return;
      setState(() {
        _details = raw;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _hm(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '$h h ${m.toString().padLeft(2, '0')}';
  }

  Color _p = const Color(0xFF7C5CFF); // accent when per-sport colors are off
  Color _stageColor(int stage) => sportColorsNotifier.value
      ? switch (stage) {
          1 => const Color(0xFF5C6BC0), // awake
          2 => const Color(0xFF7986CB), // light
          3 => const Color(0xFF3949AB), // deep
          4 => const Color(0xFF9575CD), // REM
          _ => const Color(0xFF7C5CFF),
        }
      : switch (stage) {
          1 => _p.withValues(alpha: 0.35),
          2 => _p.withValues(alpha: 0.6),
          3 => _p,
          4 => _p.withValues(alpha: 0.8),
          _ => _p,
        };

  String _stageName(int stage) => switch (stage) {
        1 => isFr ? 'Éveillé' : 'Awake',
        2 => isFr ? 'Léger' : 'Light',
        3 => isFr ? 'Profond' : 'Deep',
        4 => isFr ? 'Paradoxal' : 'REM',
        _ => isFr ? 'Sommeil' : 'Sleep',
      };

  String _sleepQuality(double hours) {
    if (hours >= 7 && hours <= 9) return isFr ? 'Bon sommeil' : 'Good sleep';
    if (hours >= 6 && hours < 7) return isFr ? 'Sommeil insuffisant' : 'Insufficient sleep';
    if (hours > 9) return isFr ? 'Sommeil long' : 'Long sleep';
    return isFr ? 'Sommeil trop court' : 'Too little sleep';
  }

  String _sleepAdvice(double hours) {
    if (hours >= 7 && hours <= 9) {
      return isFr
          ? 'Tu dors bien ! Continue à maintenir un rythme régulier.'
          : 'You\'re sleeping well! Keep up the regular schedule.';
    }
    if (hours >= 6 && hours < 7) {
      return isFr
          ? 'Essaie de gagner 30 à 60 minutes de sommeil. Couche-toi un peu plus tôt.'
          : 'Try to get 30-60 more minutes. Go to bed a bit earlier.';
    }
    if (hours > 9) {
      return isFr
          ? 'Un sommeil trop long peut indiquer de la fatigue. Vérifie ton rythme.'
          : 'Long sleep may indicate fatigue. Check your schedule.';
    }
    return isFr
        ? 'Un sommeil de moins de 6 h nuit à la récupération et à la concentration.'
        : 'Sleeping under 6 h hurts recovery and focus.';
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    _p = s.primary;
    final violet = sportColorsNotifier.value ? const Color(0xFF7C5CFF) : s.primary;
    final nights = widget.nights;
    final avg7 = nights.length >= 7
        ? nights.reversed.take(7).fold(0.0, (a, e) => a + e.$2) / 7
        : nights.isEmpty ? 0.0 : nights.fold(0.0, (a, e) => a + e.$2) / nights.length;
    final last = nights.isEmpty ? null : nights.last;
    final lastNight = _details.isNotEmpty ? _details.first : null;

    // Build chart data
    final now = DateTime.now();
    Map<String, int> chartData() {
      final out = <String, int>{};
      if (_m == 0 && lastNight != null) {
        // Show last night's stages as a timeline — use minutes of each stage
        for (final stage in lastNight.stages) {
          final key = _stageName(stage.type);
          out[key] = (out[key] ?? 0) + stage.minutes;
        }
        return out;
      }
      final n = _m == 1 ? 7 : 30;
      for (var i = n - 1; i >= 0; i--) {
        final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final k = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        final found = nights.where((e) =>
            e.$1.year == d.year && e.$1.month == d.month && e.$1.day == d.day);
        out[k] = found.isEmpty ? 0 : (found.first.$2 * 60).round(); // minutes
      }
      return out;
    }

    return Scaffold(
      appBar: AppBar(title: Text(isFr ? 'Sommeil' : 'Sleep')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: M3SegmentedButton<int>(
            segments: [
              for (final (i, l) in [
                isFr ? 'Nuit' : 'Night',
                isFr ? 'Semaine' : 'Week',
                isFr ? 'Mois' : 'Month',
              ].indexed)
                ButtonSegment(value: i, label: Text(l)),
            ],
            selected: {_m},
            onSelectionChanged: (v) => setState(() => _m = v.first),
          ),
        ),
        Divider(height: 1, thickness: 1, color: s.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
            // ── Summary card ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Color.alphaBlend(violet.withValues(alpha: 0.10), s.surfaceContainer),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: s.outlineVariant.withValues(alpha: 0.55), width: 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.bedtime_rounded, size: 22, color: violet),
              const SizedBox(width: 8),
              Text(
                _m == 0
                    ? (isFr ? 'Dernière nuit' : 'Last night')
                    : _m == 1
                        ? (isFr ? 'Moyenne 7 jours' : '7-day average')
                        : (isFr ? 'Moyenne 30 jours' : '30-day average'),
                style: t.titleSmall?.copyWith(color: violet, fontWeight: FontWeight.w800),
              ),
            ]),
            const SizedBox(height: 12),
            BigValue(
              _m == 0 ? _hm(last?.$2 ?? 0) : _hm(avg7),
              '',
            ),
            const SizedBox(height: 8),
            Text(
              _sleepQuality(_m == 0 ? (last?.$2 ?? 0) : avg7),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _sleepAdvice(_m == 0 ? (last?.$2 ?? 0) : avg7),
              style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Sleep stages (last night) ──
        if (_m == 0 && lastNight != null && lastNight.stages.isNotEmpty) ...[
          _SleepStagesChart(stages: lastNight.stages, stageColor: _stageColor, stageName: _stageName),
          const SizedBox(height: 16),
          // Stage breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: s.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isFr ? 'Répartition' : 'Breakdown',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final stage in lastNight.stages) _StageRow(
                name: _stageName(stage.type),
                minutes: stage.minutes,
                total: lastNight.totalMinutes,
                color: _stageColor(stage.type),
              ),
            ]),
          ),
        ],

        // ── Week / Month chart (same chart as the other tabs) ──
        if (_m > 0 && nights.length > 1) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final e = chartData().entries.toList();
            return ScrubChart(
              values: [for (final x in e) x.value / 60],
              color: violet, unit: 'h', decimals: 1,
              labelOf: (i) => e[i].key);
          }),
        ],

        // ── Statistics ──
        if (nights.length > 1) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: s.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isFr ? 'Statistiques' : 'Statistics',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _StatRow(
                icon: Icons.trending_up_rounded,
                label: isFr ? 'Nuit la plus longue' : 'Longest night',
                value: _hm(nights.map((e) => e.$2).reduce(math.max)),
                color: violet,
              ),
              _StatRow(
                icon: Icons.trending_down_rounded,
                label: isFr ? 'Nuit la plus courte' : 'Shortest night',
                value: _hm(nights.map((e) => e.$2).reduce(math.min)),
                color: violet,
              ),
              _StatRow(
                icon: Icons.equalizer_rounded,
                label: isFr ? 'Moyenne' : 'Average',
                value: _hm(nights.fold(0.0, (a, e) => a + e.$2) / nights.length),
                color: violet,
              ),
              _StatRow(
                icon: Icons.nights_stay_rounded,
                label: isFr ? 'Nuits enregistrées' : 'Recorded nights',
                value: '${nights.length}',
                color: violet,
              ),
            ]),
          ),
        ],

        // ── Trend chart (last 30 nights) ──
        if (_m == 0 && nights.length > 3) ...[
          const SizedBox(height: 20),
          Text((isFr ? 'Tendance' : 'Trend').toUpperCase(),
              style: t.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  color: s.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final l = nights.reversed.take(30).toList().reversed.toList();
            return ScrubChart(
              values: [for (final e in l) e.$2], color: violet, unit: 'h', decimals: 1,
              labelOf: (i) => '${l[i].$1.day.toString().padLeft(2, '0')}/${l[i].$1.month.toString().padLeft(2, '0')}');
          }),
        ],
      ])),
    ]));
  }
}

// ── Sleep stage data model ──
class _SleepStage {
  final int type; // 1=awake, 2=light, 3=deep, 4=REM
  final int minutes;
  const _SleepStage(this.type, this.minutes);
}

class _SleepNight {
  final DateTime start, end;
  final List<_SleepStage> stages;
  int get totalMinutes => stages.fold(0, (a, s) => a + s.minutes);
  const _SleepNight(this.start, this.end, this.stages);
}

// ── Extension on HealthService for sleep sessions ──
extension _SleepSessions on HealthService {
  Future<List<_SleepNight>> sleepSessions() async {
    try {
      final raw = await sleepNights();
      if (raw.isEmpty) return [];
      // Group sessions into nights and build stage breakdown from total sleep time
      // Since Health Connect may not provide stage data through our current channel,
      // we estimate stages from total sleep time using typical proportions:
      // Deep: ~20%, Light: ~50%, REM: ~25%, Awake: ~5%
      return [
        for (final n in raw.reversed.take(30))
          _SleepNight(
            n.$1.subtract(Duration(hours: n.$2.round())),
            n.$1,
            [
              _SleepStage(3, (n.$2 * 60 * 0.20).round()), // deep
              _SleepStage(2, (n.$2 * 60 * 0.50).round()), // light
              _SleepStage(4, (n.$2 * 60 * 0.25).round()), // REM
              _SleepStage(1, (n.$2 * 60 * 0.05).round()), // awake
            ],
          ),
      ];
    } catch (_) {
      return [];
    }
  }
}

// ── Sleep stages horizontal chart ──
class _SleepStagesChart extends StatelessWidget {
  final List<_SleepStage> stages;
  final Color Function(int) stageColor;
  final String Function(int) stageName;
  const _SleepStagesChart({
    required this.stages,
    required this.stageColor,
    required this.stageName,
  });

  @override
  Widget build(BuildContext c) {
    final total = stages.fold(0, (a, s) => a + s.minutes);
    if (total <= 0) return const SizedBox.shrink();
    final t = Theme.of(c).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((isFr ? 'Phases de sommeil' : 'Sleep stages').toUpperCase(),
          style: t.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(c).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, p, _) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 28,
            child: Row(children: [
              for (final s in stages)
                Expanded(
                  flex: (s.minutes * 100 / total * p).round().clamp(1, 100),
                  child: Container(
                    color: stageColor(s.type),
                    alignment: Alignment.center,
                    child: s.minutes / total > 0.12
                        ? Text(
                            '${(s.minutes / total * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 16, runSpacing: 6, children: [
        for (final s in stages)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: stageColor(s.type),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${stageName(s.type)} ${s.minutes} min',
              style: t.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ]),
      ]),
    ]);
  }
}

// ── Sleep bars chart (week / month) ──
class _SleepBarsChart extends StatelessWidget {
  final Map<String, int> data; // label -> minutes
  final Color color;
  final int targetMin;
  const _SleepBarsChart({
    required this.data,
    required this.color,
    this.targetMin = 420,
  });

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final maxMin = data.values.fold(targetMin, (a, b) => math.max(a, b));
    final entries = data.entries.toList();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, p, _) => Column(children: [
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < entries.length; i++)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: math.max(4.0, 120 * entries[i].value / maxMin * p),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withValues(alpha: entries[i].value >= targetMin ? 0.8 : 0.35),
                          color.withValues(alpha: entries[i].value >= targetMin ? 1 : 0.6),
                        ],
                      ),
                    ),
                  ),
                ]),
              )),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < entries.length; i++)
            Expanded(child: Center(
              child: Text(
                entries.length <= 10 ? entries[i].key : (i % 5 == 0 ? entries[i].key : ''),
                style: t.labelSmall?.copyWith(
                  color: s.onSurfaceVariant,
                  fontSize: 8,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            )),
        ]),
      ]),
    );
  }
}

// ── Stage row ──
class _StageRow extends StatelessWidget {
  final String name;
  final int minutes, total;
  final Color color;
  const _StageRow({
    required this.name,
    required this.minutes,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    final pct = total > 0 ? minutes / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(name, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 85,
          child: Text(
            '$minutes min · ${(pct * 100).round()}%',
            textAlign: TextAlign.end,
            style: t.labelSmall?.copyWith(color: s.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}

// ── Stat row ──
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme, s = Theme.of(c).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
        Text(value, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
