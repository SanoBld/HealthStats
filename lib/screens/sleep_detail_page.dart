// Sleep detail page: sleep cycles (deep, light, REM, awake), trends, and summaries.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/health_service.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart' show M3SegmentedButton;

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
  DateTime? _day; // chosen wake-up day (null = latest)

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
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final selDay = nights.isEmpty ? null : (_day ?? nights.last.$1);
    final selI = selDay == null ? -1 : nights.indexWhere((e) => same(e.$1, selDay));
    final selHours = selI < 0 ? 0.0 : nights[selI].$2;
    final lastNight = selDay == null ? null : _details.where((d) => same(d.end, selDay)).firstOrNull;
    final winDays = _m == 1 ? 7 : 30;
    final win = [for (final e in nights) if (DateTime.now().difference(e.$1).inDays < winDays) e];
    final avgW = win.isEmpty ? 0.0 : win.fold(0.0, (a, e) => a + e.$2) / win.length;
    String dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
            // ── Day navigator (night mode) ──
            if (_m == 0 && selI >= 0) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                IconButton(
                  onPressed: selI > 0 ? () => setState(() => _day = nights[selI - 1].$1) : null,
                  icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context, initialDate: nights[selI].$1,
                      firstDate: nights.first.$1, lastDate: nights.last.$1,
                      selectableDayPredicate: (x) => nights.any((e) => same(e.$1, x)));
                    if (d != null) setState(() => _day = d);
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text(dmy(nights[selI].$1), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)))),
                )),
                IconButton(
                  onPressed: selI < nights.length - 1 ? () => setState(() => _day = nights[selI + 1].$1) : null,
                  icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ),
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
                    ? (selDay == null || same(selDay, nights.last.$1) ? (isFr ? 'Dernière nuit' : 'Last night') : dmy(selDay))
                    : _m == 1
                        ? (isFr ? 'Moyenne 7 jours' : '7-day average')
                        : (isFr ? 'Moyenne 30 jours' : '30-day average'),
                style: t.titleSmall?.copyWith(color: violet, fontWeight: FontWeight.w800),
              ),
            ]),
            const SizedBox(height: 12),
            BigValue(
              _m == 0 ? _hm(selHours) : _hm(avgW),
              '',
            ),
            const SizedBox(height: 8),
            Text(
              _sleepQuality(_m == 0 ? selHours : avgW),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _sleepAdvice(_m == 0 ? selHours : avgW),
              style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Sleep stages (last night) ──
        if (_m == 0 && lastNight != null) ...[
          _ScoreCard(night: lastNight, all: _details, color: violet),
          if (lastNight.stages.any((e) => e.type != 0)) ...[
          const SizedBox(height: 16),
          _SleepStagesChart(night: lastNight, stageColor: _stageColor, stageName: _stageName, accent: violet),
          ],
        ],

        // ── Week / Month bars with 7 h target ──
        if (_m > 0 && nights.length > 1) ...[
          const SizedBox(height: 8),
          _SleepBarsChart(data: chartData(), color: violet, targetMin: 420),
        ],

        // ── Statistics (week / month only, on that period) ──
        if (_m > 0 && win.length > 1) ...[
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
                value: _hm(win.map((e) => e.$2).reduce(math.max)),
                color: violet,
              ),
              _StatRow(
                icon: Icons.trending_down_rounded,
                label: isFr ? 'Nuit la plus courte' : 'Shortest night',
                value: _hm(win.map((e) => e.$2).reduce(math.min)),
                color: violet,
              ),
              _StatRow(
                icon: Icons.equalizer_rounded,
                label: isFr ? 'Moyenne' : 'Average',
                value: _hm(win.fold(0.0, (a, e) => a + e.$2) / win.length),
                color: violet,
              ),
              _StatRow(
                icon: Icons.functions_rounded,
                label: isFr ? 'Total de la période' : 'Period total',
                value: '${win.fold(0.0, (a, e) => a + e.$2).round()} h',
                color: violet,
              ),
              _StatRow(
                icon: Icons.nights_stay_rounded,
                label: isFr ? 'Nuits enregistrées' : 'Recorded nights',
                value: '${win.length}',
                color: violet,
              ),
            ]),
          ),
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
  /// One entry per night (newest first), whole history, with the real stages.
  Future<List<_SleepNight>> sleepSessions() async {
    try {
      final byDay = <DateTime, List<Map>>{};
      for (final m in await sleepRaw()) {
        final b = DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt());
        (byDay[DateTime(b.year, b.month, b.day)] ??= []).add(m);
      }
      final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
      return [for (final d in days) _buildNight(byDay[d]!)];
    } catch (_) {
      return [];
    }
  }
}

_SleepNight _buildNight(List<Map> ss) {
  DateTime t(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
  final start = ss.map((m) => t(m['start'])).reduce((a, b) => a.isBefore(b) ? a : b);
  final end = ss.map((m) => t(m['end'])).reduce((a, b) => a.isAfter(b) ? a : b);
  final st = <(int, int, int)>[];
  for (final m in ss) {
    for (final e in (m['stages'] as List? ?? const [])) {
      final l = (e as List).cast<num>();
      if (l[0] > 0) st.add((l[0].toInt(), l[1].toInt(), l[2].toInt()));
    }
  }
  st.sort((a, b) => a.$2.compareTo(b.$2));
  // no stage data from the source: one plain block (nothing is guessed)
  final stages = st.isEmpty
      ? [_SleepStage(0, end.difference(start).inMinutes)]
      : [for (final e in st) _SleepStage(e.$1, ((e.$3 - e.$2) / 60000).round())];
  return _SleepNight(start, end, stages);
}

// ── Card helper (same card as the charts) ──
BoxDecoration _sleepCard(ColorScheme s, Color tint) => BoxDecoration(
      color: Color.alphaBlend(tint.withValues(alpha: 0.10), s.surfaceContainer),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
    );

String _clk(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
double _tod(DateTime d) { // minutes since 18:00 so that night times stay continuous
  var m = d.hour * 60.0 + d.minute - 18 * 60;
  if (m < 0) m += 1440;
  return m;
}

// ── Sleep score (like Apple: duration / bedtime / interruptions) ──
class _ScoreCard extends StatelessWidget {
  final _SleepNight night; final List<_SleepNight> all; final Color color;
  const _ScoreCard({required this.night, required this.all, required this.color});

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final dur = (night.totalMinutes / 480 * 50).clamp(0, 50).toDouble();
    final hasSt = night.stages.any((e) => e.type != 0);
    final awake = night.stages.where((e) => e.type == 1).length;
    final inter = (20 - awake * 4).clamp(0, 20).toDouble();
    final others = all.where((e) => e.start != night.start).toList();
    double? diff; // minutes later than the usual bedtime (negative = earlier)
    if (others.isNotEmpty) {
      final avg = others.fold(0.0, (a, e) => a + _tod(e.start)) / others.length;
      diff = _tod(night.start) - avg;
    }
    final bed = diff == null ? 30.0 : (30 - diff.abs() / 2).clamp(0, 30).toDouble();
    final scale = hasSt ? 100.0 : 80.0; // no stages = no interruptions part
    final score = ((dur + bed + (hasSt ? inter : 0)) / scale * 100).round();
    final label = score >= 80 ? (isFr ? 'Élevé' : 'High') : score >= 60 ? (isFr ? 'Moyen' : 'Medium') : (isFr ? 'Faible' : 'Low');
    final sentence = diff == null
        ? (isFr ? 'Ton score est calculé sur la durée et les interruptions.' : 'Your score is based on duration and interruptions.')
        : diff.abs() < 10
            ? (isFr ? 'Tu t\'es couché à ton heure habituelle.' : 'You went to bed at your usual time.')
            : diff < 0
                ? (isFr ? 'Tu t\'es couché ${diff.abs().round()} min plus tôt que d\'habitude.' : 'You went to bed ${diff.abs().round()} min earlier than usual.')
                : (isFr ? 'Tu t\'es couché ${diff.round()} min plus tard que d\'habitude.' : 'You went to bed ${diff.round()} min later than usual.');
    Widget row(Color col, String name, double v, int max) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: t.bodySmall)),
            Text('${v.round()}/$max', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sleepCard(s, color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bedtime_rounded, size: 18, color: color), const SizedBox(width: 6),
          Text(isFr ? 'Score de sommeil' : 'Sleep score', style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            row(color, isFr ? 'Durée' : 'Duration', dur, 50),
            row(color.withValues(alpha: 0.65), isFr ? 'Heure de coucher' : 'Bedtime', bed, 30),
            if (hasSt) row(color.withValues(alpha: 0.35), 'Interruptions', inter, 20),
          ])),
          const SizedBox(width: 12),
          SizedBox(width: 96, height: 96, child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
            builder: (_, p, _) => CustomPaint(
              painter: _RingPainter([dur / scale, bed / scale, hasSt ? inter / scale : 0.0], [color, color.withValues(alpha: 0.65), color.withValues(alpha: 0.35)],
                  s.surfaceContainerHighest, p),
              child: Center(child: Text('$score', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            ),
          )),
        ]),
        const SizedBox(height: 12),
        Text(sentence, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.3)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<double> parts; final List<Color> cols; final Color track; final double p;
  _RingPainter(this.parts, this.cols, this.track, this.p);
  @override
  void paint(Canvas c, Size size) {
    final r = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 11..color = track;
    c.drawArc(r, 0, 6.2832, false, base);
    var a = -1.5708;
    for (var i = 0; i < parts.length; i++) {
      final sw = 6.2832 * parts[i] * p;
      if (sw > 0.02) {
        c.drawArc(r, a, sw - 0.04, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round..color = cols[i]);
      }
      a += 6.2832 * parts[i] * p;
    }
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.p != p || o.parts != parts;
}

// ── Sleep stages timeline (like Apple: one row per stage, blocks over time) ──
class _SleepStagesChart extends StatelessWidget {
  final _SleepNight night; final Color accent;
  final Color Function(int) stageColor;
  final String Function(int) stageName;
  const _SleepStagesChart({required this.night, required this.stageColor, required this.stageName, required this.accent});

  @override
  Widget build(BuildContext c) {
    final stages = night.stages;
    final total = stages.fold(0, (a, e) => a + e.minutes);
    if (total <= 0) return const SizedBox.shrink();
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    const rows = [1, 4, 2, 3]; // awake, REM, light, deep
    final sums = {for (final r in rows) r: stages.where((e) => e.type == r).fold(0, (a, e) => a + e.minutes)};
    String dm(int m) => m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _sleepCard(s, accent),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.stacked_line_chart_rounded, size: 18, color: accent), const SizedBox(width: 6),
          Text(isFr ? 'Phases de sommeil' : 'Sleep stages', style: t.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
          builder: (_, p, _) => SizedBox(height: 150, width: double.infinity, child: CustomPaint(
            painter: _HypnoPainter(stages, total, rows, stageColor, stageName, s.onSurfaceVariant,
                s.outlineVariant.withValues(alpha: 0.35), _clk(night.start), _clk(night.end), p))),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final r in rows) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: stageColor(r), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Flexible(child: Text(stageName(r), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(color: s.onSurfaceVariant, fontSize: 10))),
            ]),
            const SizedBox(height: 2),
            Text(dm(sums[r] ?? 0), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ])),
        ]),
      ]),
    );
  }
}

class _HypnoPainter extends CustomPainter {
  final List<_SleepStage> st; final int total; final List<int> rows;
  final Color Function(int) col; final String Function(int) name;
  final Color text, grid; final String t0, t1; final double p;
  _HypnoPainter(this.st, this.total, this.rows, this.col, this.name, this.text, this.grid, this.t0, this.t1, this.p);
  void _txt(Canvas c, String s, Offset o, ) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o);
  }
  @override
  void paint(Canvas c, Size size) {
    const padL = 52.0, bottom = 18.0;
    final w = size.width - padL, rh = (size.height - bottom) / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final y = rh * i + rh / 2;
      c.drawLine(Offset(padL, y), Offset(size.width, y), Paint()..color = grid..strokeWidth = 1);
      _txt(c, name(rows[i]), Offset(0, y - 5));
    }
    c.save();
    c.clipRect(Rect.fromLTWH(padL, 0, w * p, size.height));
    var cum = 0;
    for (final e in st) {
      final i = rows.indexOf(e.type);
      if (i >= 0) {
        final x = padL + w * cum / total, bw = (w * e.minutes / total).clamp(3.0, w);
        final y = rh * i + rh / 2;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - rh * 0.3, bw, rh * 0.6), const Radius.circular(5)),
            Paint()..color = col(e.type));
      }
      cum += e.minutes;
    }
    c.restore();
    _txt(c, t0, Offset(padL, size.height - 10));
    _txt(c, t1, Offset(size.width - 26, size.height - 10));
  }
  @override
  bool shouldRepaint(_HypnoPainter o) => o.p != p || o.st != st;
}

// ── Sleep bars (week / month): target line, last night highlighted, tap to read ──
class _SleepBarsChart extends StatefulWidget {
  final Map<String, int> data; // label -> minutes
  final Color color;
  final int targetMin;
  const _SleepBarsChart({required this.data, required this.color, this.targetMin = 420});
  @override
  State<_SleepBarsChart> createState() => _SleepBarsChartState();
}

class _SleepBarsChartState extends State<_SleepBarsChart> {
  int? _sel;
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final e = widget.data.entries.toList();
    final maxMin = e.fold(widget.targetMin, (a, x) => math.max(a, x.value));
    final done = e.where((x) => x.value > 0).toList();
    final avg = done.isEmpty ? 0 : done.fold(0, (a, x) => a + x.value) ~/ done.length;
    String hm(int m) => '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
    final si = _sel ?? (e.isEmpty ? null : e.length - 1);
    const h = 150.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _sleepCard(s, widget.color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: widget.color), const SizedBox(width: 6),
          Text(isFr ? 'Durée par nuit' : 'Duration per night', style: t.labelLarge?.copyWith(color: widget.color, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (si != null) Text('${e[si].key} · ${e[si].value > 0 ? hm(e[si].value) : '–'}',
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic,
          builder: (_, p, _) => SizedBox(height: h, child: Stack(children: [
            Positioned(left: 0, right: 0, bottom: h * widget.targetMin / maxMin,
                child: Container(height: 1.5, color: s.tertiary.withValues(alpha: 0.7))),
            Positioned(right: 0, bottom: h * widget.targetMin / maxMin + 3,
                child: Text('${widget.targetMin ~/ 60} h', style: t.labelSmall?.copyWith(color: s.tertiary, fontSize: 9, fontWeight: FontWeight.w700))),
            LayoutBuilder(builder: (_, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(() => _sel = (d.localPosition.dx / box.maxWidth * e.length).floor().clamp(0, e.length - 1)),
              onHorizontalDragUpdate: (d) => setState(() => _sel = (d.localPosition.dx / box.maxWidth * e.length).floor().clamp(0, e.length - 1)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < e.length; i++) Expanded(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: e.length > 14 ? 1 : 3),
                  child: Align(alignment: Alignment.bottomCenter, child: Container(
                    height: math.max(4.0, h * e[i].value / maxMin * p),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: i == si ? widget.color : widget.color.withValues(alpha: e[i].value >= widget.targetMin ? 0.6 : 0.3)),
                  )),
                )),
              ]),
            )),
          ])),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < e.length; i++) Expanded(child: Center(child: Text(
            e.length <= 10 ? e[i].key : (i % 5 == 0 ? e[i].key : ''),
            maxLines: 1, overflow: TextOverflow.clip,
            style: t.labelSmall?.copyWith(color: s.onSurfaceVariant, fontSize: 8)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatBadge(icon: Icons.equalizer_rounded, label: isFr ? 'Moy.' : 'Avg', value: hm(avg), color: widget.color)),
          const SizedBox(width: 8),
          Expanded(child: StatBadge(icon: Icons.trending_up_rounded, label: 'Max', value: hm(done.isEmpty ? 0 : done.map((x) => x.value).reduce(math.max)), color: s.tertiary)),
          const SizedBox(width: 8),
          Expanded(child: StatBadge(icon: Icons.trending_down_rounded, label: 'Min', value: hm(done.isEmpty ? 0 : done.map((x) => x.value).reduce(math.min)), color: s.outline)),
        ]),
      ]),
    );
  }
}

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
