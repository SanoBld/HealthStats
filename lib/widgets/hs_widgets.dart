// Small shared HealthStats components (LastStats card style).
import 'package:flutter/material.dart';
import '../models/health_models.dart';
import '../l10n/l10n.dart';
import '../app_state.dart';

bool get isFr => localeNotifier.value == 'fr';
String sportName(SportInfo s) => isFr ? s.fr : s.en;
String fmtDate(DateTime d) {
  final m = isFr
      ? ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.']
      : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
String distLabel(double m) => unitsMetricNotifier.value ? '${fmtKm(m)} km' : '${(m / 1609.344).toStringAsFixed(2)} mi';

class SectionTitle extends StatelessWidget {
  final String text; final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(),
              style: Theme.of(c).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2, color: Theme.of(c).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatTile extends StatelessWidget {
  final IconData icon; final String value, label; final Color? color;
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: s.surfaceContainer, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color ?? s.primary),
        const SizedBox(height: 10),
        Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
      ]),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<StatTile> tiles;
  const StatGrid(this.tiles, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(builder: (_, b) {
          final w = (b.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        }),
      );
}

class WorkoutCard extends StatelessWidget {
  final Workout w; final VoidCallback onTap;
  const WorkoutCard({super.key, required this.w, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme, sp = w.sport;
    final parts = <String>[
      fmtDuration(w.duration),
      if (w.distanceM > 100) distLabel(w.distanceM),
      if (w.kcal > 0) '${w.kcal.round()} kcal',
      if (sp.strength && w.totalReps > 0) '${w.totalReps} rép.',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: s.surfaceContainer, borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: sp.color.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(sp.icon, color: sp.color)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.title.isNotEmpty ? w.title : sportName(sp), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(fmtDate(w.start), style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(parts.join(' · '), style: t.bodyMedium),
              ])),
              if (w.hasRoute) Icon(Icons.route_rounded, size: 18, color: s.onSurfaceVariant),
              Icon(Icons.chevron_right_rounded, color: s.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Progress ring (today's steps).
class RingProgress extends StatelessWidget {
  final double value; final String center, caption; final double size;
  const RingProgress({super.key, required this.value, required this.center, required this.caption, this.size = 130});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: size, height: size, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
        builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: 10, strokeCap: StrokeCap.round,
            backgroundColor: s.surfaceContainerHighest, color: s.primary))),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text(caption, style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
      ]),
    ]));
  }
}

/// Simple line chart (heart rate, elevation…).
class LineSpark extends StatelessWidget {
  final List<double> values; final Color color; final double height;
  const LineSpark({super.key, required this.values, required this.color, this.height = 120});
  @override
  Widget build(BuildContext c) => SizedBox(height: height, width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color, Theme.of(c).colorScheme.outlineVariant,
          Theme.of(c).colorScheme.onSurfaceVariant)));
}
class _SparkPainter extends CustomPainter {
  final List<double> v; final Color color, grid, text;
  _SparkPainter(this.v, this.color, this.grid, this.text);
  @override
  void paint(Canvas c, Size size) {
    if (v.length < 2) return;
    var lo = v.reduce((a, b) => a < b ? a : b), hi = v.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) { hi = lo + 1; }
    const pl = 30.0;
    final w = size.width - pl, h = size.height - 6;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = pl + w * i / (v.length - 1), y = 3 + h * (1 - (v[i] - lo) / (hi - lo));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)..lineTo(size.width, size.height)..lineTo(pl, size.height)..close();
    c.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)]).createShader(Offset.zero & size));
    c.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    for (final (val, y) in [(hi, 8.0), (lo, size.height - 6)]) {
      final tp = TextPainter(text: TextSpan(text: val.round().toString(), style: TextStyle(color: text, fontSize: 10)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(0, y - tp.height / 2));
    }
  }
  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v;
}
