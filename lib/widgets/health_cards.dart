// Apple Health / Android Health style building blocks.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

class HealthCard extends StatelessWidget {
  final IconData icon; final String title; final Color color; final Widget child;
  final VoidCallback? onTap; final String? trailing;
  const HealthCard({super.key, required this.icon, required this.title, required this.color,
      required this.child, this.onTap, this.trailing});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), s.surfaceContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: s.outlineVariant.withValues(alpha: 0.55), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: color), const SizedBox(width: 8),
              Expanded(child: Text(title, style: t.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800))),
              if (trailing != null) Text(trailing!, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: s.onSurfaceVariant),
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        )),
      ),
    );
  }
}

/// Big number + small unit.
class BigValue extends StatelessWidget {
  final String value, unit; final String? caption;
  const BigValue(this.value, this.unit, {super.key, this.caption});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        Text(unit, style: t.labelLarge?.copyWith(color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ]),
      if (caption != null) Text(caption!, style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
    ]);
  }
}

/// Smooth rounded area sparkline, same look as the trend chart.
class MiniArea extends StatelessWidget {
  final List<double> v; final Color color; final double height;
  const MiniArea({super.key, required this.v, required this.color, this.height = 64});
  @override
  Widget build(BuildContext c) => SizedBox(height: height, width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
        builder: (_, p, _) => CustomPaint(painter: _MiniPainter(v, color, Theme.of(c).colorScheme.tertiary, p)),
      ));
}

class _MiniPainter extends CustomPainter {
  final List<double> v; final Color color, accent; final double p;
  _MiniPainter(this.v, this.color, this.accent, this.p);
  @override
  void paint(Canvas c, Size size) {
    final n = v.length;
    if (n < 2) return;
    var lo = v.reduce(math.min), hi = v.reduce(math.max);
    if (hi - lo < 1e-6) { hi = lo + 1; }
    const pad = 6.0;
    final h = size.height - pad * 2;
    final pts = [for (var i = 0; i < n; i++) Offset(pad + (size.width - pad * 2) * i / (n - 1), pad + h * (1 - (v[i] - lo) / (hi - lo)))];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[math.max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(i + 2, n - 1)];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy.clamp(pad, pad + h).toDouble(), c2.dx, c2.dy.clamp(pad, pad + h).toDouble(), p2.dx, p2.dy);
    }
    c.save();
    c.clipRect(Rect.fromLTRB(0, 0, size.width * p, size.height));
    c.drawPath(Path.from(path)..lineTo(pts.last.dx, size.height)..lineTo(pts.first.dx, size.height)..close(),
        Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.35), accent.withValues(alpha: 0.02)]).createShader(Offset.zero & size));
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: [color, accent]).createShader(Offset.zero & size));
    c.restore();
    if (p >= 1) {
      c.drawCircle(pts.last, 5, Paint()..color = Colors.white);
      c.drawCircle(pts.last, 3.2, Paint()..color = accent);
    }
  }
  @override
  bool shouldRepaint(_MiniPainter o) => o.v != v || o.p != p || o.color != color;
}

/// Rounded vertical bars (e.g. sleep of the last nights), last one highlighted.
class MiniBars extends StatelessWidget {
  final List<(DateTime, double)> data; final Color color; final double height;
  const MiniBars({super.key, required this.data, required this.color, this.height = 70});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final mx = data.fold<double>(1, (a, e) => math.max(a, e.$2));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic,
      builder: (_, p, _) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < data.length; i++) Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(height: math.max(6.0, (height - 18) * data[i].$2 / mx * p), margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [color.withValues(alpha: i == data.length - 1 ? 0.55 : 0.25), color.withValues(alpha: i == data.length - 1 ? 1 : 0.55)]))),
          const SizedBox(height: 4),
          Text(L.weekdaysShort[data[i].$1.weekday - 1].substring(0, 1).toUpperCase(),
              style: t.labelSmall?.copyWith(color: s.onSurfaceVariant, fontSize: 10)),
        ])),
      ]),
    );
  }
}

/// Night timeline: bed time -> wake time on a rounded track.
class SleepSpan extends StatelessWidget {
  final DateTime start, end; final Color color;
  const SleepSpan({super.key, required this.start, required this.end, required this.color});
  String _h(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    return Column(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
        builder: (_, p, _) => Container(height: 22, decoration: BoxDecoration(color: s.surfaceContainerHighest.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(11)),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: p,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color]))))),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.bedtime_rounded, size: 14, color: s.onSurfaceVariant), const SizedBox(width: 4),
        Text(_h(start), style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(_h(end), style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(width: 4),
        Icon(Icons.wb_sunny_rounded, size: 14, color: s.onSurfaceVariant),
      ]),
    ]);
  }
}
