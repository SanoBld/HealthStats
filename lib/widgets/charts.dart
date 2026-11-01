// lib/widgets/charts.dart
// Graphiques repris de LastStats (_charts_visuals.dart) : tendance zoomable,
// barres par jour de semaine, donut de répartition. Données = séances santé.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/extra_strings.dart';
import '../l10n/l10n.dart';
import '../theme/m3_interaction.dart';
import 'm3_components.dart';

const bool _chartExportMode = false;
const Color? _exportBgColor = null;
enum _HapticImpact { selection }
void _haptic(_HapticImpact _) => HapticFeedback.selectionClick();
List<String> get _chartWeekdayLabels => L.weekdaysShort;
String _fmtExact(int n) => _fmt(n);
/// 'YYYY-MM' -> 'MM/YY' ; 'YYYY-MM-DD' -> 'DD/MM'
String _monthShort(String key) {
  final d = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(key);
  if (d != null) return '${d.group(3)!.padLeft(2, '0')}/${d.group(2)!.padLeft(2, '0')}';
  final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(key);
  return m == null ? key : '${m.group(2)!.padLeft(2, '0')}/${m.group(1)!.substring(2)}';
}

class TrendChart extends StatefulWidget {
  final Map<String, int> monthly;
  const TrendChart({super.key, required this.monthly});
  @override
  State<TrendChart> createState() => TrendChartState();
}

class TrendChartState extends State<TrendChart> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  bool _cumul = false;
  int? _sel;

  // Zoom: _zoom >= 1, _lo = first visible index (in index units)
  double _zoom = 1, _lo = 0;
  double _gZoom = 1, _gLo = 0, _gFx = 0;

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _setMode(bool c) {
    setState(() { _cumul = c; _sel = null; });
    _anim.forward(from: 0);
  }

  double _maxZoom(int n) => n <= 3 ? 1 : math.min(16.0, (n - 1) / 2);
  double _span(int n, double z) => n <= 1 ? 0 : (n - 1) / z;
  double _clampLo(int n, double lo, double span) =>
      n <= 1 ? 0 : lo.clamp(0.0, math.max(0.0, (n - 1) - span)).toDouble();

  // Zoom around a screen fraction (0..1) of the plot area
  void _zoomTo(int n, double z, double frac) {
    z = z.clamp(1.0, _maxZoom(n)).toDouble();
    final oldSpan = _span(n, _zoom);
    final anchor = _lo + frac * oldSpan;
    final span = _span(n, z);
    setState(() {
      _zoom = z;
      _lo = _clampLo(n, anchor - frac * span, span);
      _sel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final keys = widget.monthly.keys.toList()..sort();
    final raw  = [for (final k in keys) widget.monthly[k]!.toDouble()];
    var acc = 0.0;
    final vals = _cumul ? [for (final v in raw) acc += v] : raw;
    final total = raw.fold<double>(0, (a, b) => a + b).round();
    final avg   = raw.isEmpty ? 0 : (total / raw.length).round();
    var bestI = 0;
    for (var i = 0; i < raw.length; i++) { if (raw[i] > raw[bestI]) bestI = i; }
    final labels = [for (final k in keys) _monthShort(k)];

    final bg = _cardBg(s, s.primaryContainer);
    return Container(
      decoration: _chartCardDecoration(s, s.primaryContainer),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _ChipStat(label: tx('ui_total'), value: _fmt(total), s: s, t: t,
              bg: s.primaryContainer, fg: s.onPrimaryContainer),
          _ChipStat(label: tx('ui_avg_mo'), value: _fmt(avg), s: s, t: t,
              bg: s.secondaryContainer, fg: s.onSecondaryContainer),
          if (raw.isNotEmpty)
            _ChipStat(label: tx('cx_best_month'), value: labels[bestI], s: s, t: t,
                bg: s.tertiaryContainer, fg: s.onTertiaryContainer),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: M3SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(tx('cx_by_month'))),
                ButtonSegment(value: true,  label: Text(tx('cx_cumulative'))),
              ],
              selected: {_cumul},
              onSelectionChanged: (v) => _setMode(v.first),
            ),
          ),
          if (raw.length > 3) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: _zoom > 1 ? () => _zoomTo(raw.length, _zoom / 1.6, 0.5) : null,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: _zoom < _maxZoom(raw.length)
                  ? () => _zoomTo(raw.length, _zoom * 1.6, 0.5) : null,
            ),
          ],
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 230,
          child: LayoutBuilder(builder: (ctx, c) {
            final n = vals.length;
            final pw = c.maxWidth - _TrendPainter.padL - _TrendPainter.padR;
            final span = _span(n, _zoom);
            final lo = _clampLo(n, _lo, span);
            void pick(Offset p) {
              if (n == 0) return;
              final i = n == 1 ? 0
                  : (lo + ((p.dx - _TrendPainter.padL) / pw) * span).round()
                      .clamp(0, n - 1).toInt();
              if (i != _sel) setState(() => _sel = i);
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition),
              onDoubleTap: () => _zoomTo(n, 1, 0.5),
              onScaleStart: (d) {
                _gZoom = _zoom; _gLo = lo; _gFx = d.localFocalPoint.dx;
                if (d.pointerCount == 1 && _zoom <= 1) pick(d.localFocalPoint);
              },
              onScaleUpdate: (d) {
                if (n < 2 || pw <= 0) return;
                if (d.pointerCount >= 2) {
                  final z = (_gZoom * d.scale).clamp(1.0, _maxZoom(n)).toDouble();
                  final startSpan = _span(n, _gZoom);
                  final anchor = _gLo + ((_gFx - _TrendPainter.padL) / pw) * startSpan;
                  final ns = _span(n, z);
                  final frac = (d.localFocalPoint.dx - _TrendPainter.padL) / pw;
                  setState(() {
                    _zoom = z;
                    _lo = _clampLo(n, anchor - frac * ns, ns);
                    _sel = null;
                  });
                } else if (_zoom > 1) {
                  final startSpan = _span(n, _gZoom);
                  final dIdx = (d.localFocalPoint.dx - _gFx) / pw * startSpan;
                  setState(() => _lo = _clampLo(n, _gLo - dIdx, startSpan));
                } else {
                  pick(d.localFocalPoint);
                }
              },
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => CustomPaint(
                  size: Size(c.maxWidth, 230),
                  painter: _TrendPainter(
                    v: vals, labels: labels,
                    progress: Curves.easeOutCubic.transform(_anim.value),
                    sel: _sel, lo: lo, hi: lo + span,
                    line: s.primary, accent: s.tertiary,
                    grid: s.outlineVariant.withValues(alpha: 0.45),
                    text: s.onSurfaceVariant, surface: bg,
                    onSurface: s.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> v;
  final List<String> labels;
  final double progress;
  final int? sel;
  final double lo, hi;
  final Color line, accent, grid, text, surface, onSurface;
  static const padL = 38.0, padR = 10.0, padT = 28.0, padB = 24.0;

  _TrendPainter({required this.v, required this.labels, required this.progress, required this.sel,
      required this.lo, required this.hi,
      required this.line, required this.accent, required this.grid, required this.text,
      required this.surface, required this.onSurface});

  @override
  void paint(Canvas canvas, Size size) {
    final n = v.length;
    if (n == 0) return;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final i0 = lo.floor().clamp(0, n - 1).toInt();
    final i1 = hi.ceil().clamp(0, n - 1).toInt();
    var maxV = 0.0;
    for (var i = i0; i <= i1; i++) { if (v[i] > maxV) maxV = v[i]; }
    if (maxV <= 0) maxV = 1;
    final span = hi - lo;
    double x(int i) => (n == 1 || span <= 0) ? padL + w / 2 : padL + w * (i - lo) / span;
    double y(double val) => padT + h * (1 - val / maxV);

    // grid + y labels
    final gp = Paint()..color = grid..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final yy = padT + h * g / 3;
      canvas.drawLine(Offset(padL, yy), Offset(size.width - padR, yy), gp);
      _paintText(canvas, _fmt((maxV * (1 - g / 3)).round()), Offset(padL - 6, yy),
          color: text, size: 9, align: 2);
    }

    final pts = [for (var i = 0; i < n; i++) Offset(x(i), y(v[i]))];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[math.max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(i + 2, n - 1)];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy.clamp(padT, padT + h).toDouble(), c2.dx, c2.dy.clamp(padT, padT + h).toDouble(), p2.dx, p2.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(padL - 6, 0, math.min(size.width, padL + w * progress + 6), size.height));
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, padT + h)
      ..lineTo(pts.first.dx, padT + h)
      ..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [line.withValues(alpha: 0.38), accent.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(padL, padT, w, h)));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: [line, accent])
          .createShader(Rect.fromLTWH(padL, padT, w, h)));
    if (span <= 24) {
      for (var i = i0; i <= i1; i++) {
        canvas.drawCircle(pts[i], 4, Paint()..color = surface);
        canvas.drawCircle(pts[i], 2.5, Paint()..color = line);
      }
    }
    canvas.restore();

    // x labels: first, middle, last
    final idxs = <int>{for (var k = 0; k <= 3; k++) (lo + span * k / 3).round().clamp(0, n - 1).toInt()};
    for (final i in idxs) {
      _paintText(canvas, labels[i], Offset(pts[i].dx.clamp(padL + 14, size.width - padR - 14).toDouble(), size.height - 8),
          color: text, size: 9);
    }

    // selection: guide line, dot, bubble
    final si = sel;
    if (si != null && si < n && si >= lo - 0.5 && si <= hi + 0.5) {
      final p = pts[si];
      canvas.drawLine(Offset(p.dx, padT), Offset(p.dx, padT + h),
          Paint()..color = accent.withValues(alpha: 0.4)..strokeWidth = 1.5);
      canvas.drawCircle(p, 8, Paint()..color = surface);
      canvas.drawCircle(p, 5.5, Paint()..color = accent);
      final tp = TextPainter(
        text: TextSpan(
          text: '${labels[si]} · ${_fmtExact(v[si].round())}',
          style: TextStyle(color: surface, fontSize: 11, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final bw = tp.width + 18, bh = tp.height + 10;
      final bx = (p.dx - bw / 2).clamp(0.0, size.width - bw).toDouble();
      final by = math.max(0.0, p.dy - bh - 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(12)),
        Paint()..color = onSurface);
      tp.paint(canvas, Offset(bx + 9, by + 5));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter o) =>
      o.progress != progress || o.sel != sel || o.v != v || o.line != line || o.lo != lo || o.hi != hi;
}

class WeekChart extends StatefulWidget {
  final Map<int, int> data;
  const WeekChart({required this.data});
  @override
  State<WeekChart> createState() => WeekChartState();
}

class WeekChartState extends State<WeekChart> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final data = widget.data;
    final labels = _chartWeekdayLabels;
    final maxV = data.values.fold(0, (a, b) => a > b ? a : b);
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final peak = data.isEmpty ? 1
        : data.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return Container(
      decoration: _chartCardDecoration(s, s.secondaryContainer),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tx('ui_activity_by_day_of_wee'),
              style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
          _PeakChip(label: '📅 ${labels[peak - 1]}',
              color: s.tertiaryContainer, onColor: s.onTertiaryContainer, t: t),
        ]),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _chartExportMode ? 1.0 : 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, p, _) => Column(children: [
            for (var d = 1; d <= 7; d++) Builder(builder: (_) {
              final v = data[d] ?? 0;
              final ratio = maxV > 0 ? v / maxV : 0.0;
              final isPeak = d == peak && maxV > 0;
              final isSel = _sel == d;
              final pct = total > 0 ? v * 100 / total : 0.0;
              final fg = isPeak ? s.tertiary : s.primary;
              return M3InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () { _haptic(_HapticImpact.selection); setState(() => _sel = isSel ? null : d); },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? s.surfaceContainerHighest.withValues(alpha: 0.7) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text(labels[d - 1], style: t.labelMedium?.copyWith(
                        color: isPeak ? s.tertiary : s.onSurfaceVariant,
                        fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600))),
                    Expanded(child: LayoutBuilder(builder: (_, c) => Stack(children: [
                      Container(height: 14, decoration: BoxDecoration(
                          color: s.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(7))),
                      Container(
                        height: 14,
                        width: math.max(14.0, c.maxWidth * ratio * p),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(colors: [fg.withValues(alpha: 0.45), fg])),
                      ),
                    ]))),
                    const SizedBox(width: 10),
                    SizedBox(width: _chartExportMode ? 104 : 64, child: Text(
                      _chartExportMode
                          ? (v > 0 ? '${_fmt(v)} · ${pct.round()}%' : '–')
                          : isSel ? '${pct.toStringAsFixed(1)}%' : (v > 0 ? _fmt(v) : '–'),
                      textAlign: TextAlign.end,
                      style: t.labelMedium?.copyWith(
                        color: isPeak ? s.tertiary : s.onSurface,
                        fontWeight: isPeak || isSel ? FontWeight.w800 : FontWeight.w600))),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label, value;
  final ColorScheme s;
  final TextTheme   t;
  final Color? bg, fg;
  const _ChipStat({required this.label, required this.value,
      required this.s, required this.t, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final f = fg ?? s.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? s.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: t.labelSmall
            ?.copyWith(color: f.withValues(alpha: 0.75), fontSize: 11)),
        const SizedBox(width: 6),
        Text(value, style: t.labelSmall?.copyWith(
            color: f, fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
    );
  }
}

class _PeakChip extends StatelessWidget {
  final String label;
  final Color  color, onColor;
  final TextTheme t;
  const _PeakChip({required this.label, required this.color,
      required this.onColor, required this.t});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(24)),
    child: Text(label,
        style: t.labelSmall?.copyWith(
            color: onColor, fontWeight: FontWeight.w700)),
  );
}

class ShareDonut extends StatelessWidget {
  final List<dynamic> items;
  final String Function(dynamic) getLabel;
  final int Function(dynamic) getPlays;
  final void Function(dynamic)? onTap;
  final Color? textColor;
  const ShareDonut({required this.items, required this.getLabel,
      required this.getPlays, this.onTap, this.textColor});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final top = items.take(5).toList();
    final total = items.fold<int>(0, (a, e) => a + getPlays(e));
    final vals = [for (final e in top) getPlays(e)];
    final rest = total - vals.fold<int>(0, (a, b) => a + b);
    final palette = _themePalette(s);
    final segs = [...vals, if (rest > 0) rest];
    String pct(int v) => total > 0 ? '${(v * 100 / total).round()}%' : '';

    return Container(
      decoration: _chartCardDecoration(s, s.primaryContainer),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _chartExportMode ? 1.0 : 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, p, _) => SizedBox(
            width: 150, height: 150,
            child: CustomPaint(
              painter: _DonutShare(values: segs, colors: palette, progress: p,
                  bg: s.surfaceContainerHighest),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmt(total), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: textColor)),
                Text(L.commonPlays, style: t.labelSmall?.copyWith(color: textColor ?? s.onSurfaceVariant)),
              ])),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(children: [
          for (var i = 0; i < top.length; i++)
            M3InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap == null ? null : () => onTap!(top[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(width: 12, height: 12,
                      decoration: BoxDecoration(color: palette[i], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(getLabel(top[i]), maxLines: _chartExportMode ? 2 : 1, overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: textColor))),
                  const SizedBox(width: 6),
                  Text(_chartExportMode ? '${pct(vals[i])} · ${_fmt(vals[i])}' : pct(vals[i]),
                      style: t.labelSmall?.copyWith(color: textColor ?? s.onSurfaceVariant)),
                ]),
              ),
            ),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: palette[5], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(tx('cx_others'), style: t.bodySmall?.copyWith(
                    color: s.onSurfaceVariant, fontWeight: FontWeight.w600))),
                Text(pct(rest), style: t.labelSmall?.copyWith(color: s.onSurfaceVariant)),
              ]),
            ),
        ])),
      ]),
    );
  }
}

class _DonutShare extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final double progress;
  final Color bg;
  _DonutShare({required this.values, required this.colors, required this.progress, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 30.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final total = values.fold<int>(0, (a, b) => a + b);
    canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = stroke..color = bg);
    if (total <= 0) return;
    final gap = values.length > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final full = values[i] / total * 2 * math.pi;
      final sweep = math.max(0.0, full - gap) * progress;
      if (sweep > 0) {
        canvas.drawArc(rect, start + gap / 2, sweep, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i % colors.length]);
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(_DonutShare o) => o.progress != progress || o.values != values;
}

BoxDecoration _chartCardDecoration(ColorScheme s, [Color? tint]) => _chartExportMode
    ? const BoxDecoration()
    : BoxDecoration(
  color: _cardBg(s, tint),
  borderRadius: BorderRadius.circular(28),
);

Color _cardBg(ColorScheme s, [Color? tint]) => (_chartExportMode && _exportBgColor != null)
    ? _exportBgColor!
    : tint == null
    ? s.surfaceContainerLow
    : Color.alphaBlend(tint.withValues(alpha: 0.32), s.surfaceContainerLow);

void _paintText(Canvas c, String text, Offset o,
    {required Color color, double size = 10, FontWeight weight = FontWeight.w600, int align = 1}

Color _onColor(Color c) =>
    ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black;

List<Color> _themePalette(ColorScheme s) {
  final p = HSLColor.fromColor(s.primary);
  final dark = s.brightness == Brightness.dark;
  final ls = dark ? const [0.82, 0.70, 0.58, 0.47, 0.37]
                  : const [0.28, 0.40, 0.52, 0.64, 0.76];
  return [
    for (final l in ls)
      HSLColor.fromAHSL(1, p.hue, math.max(p.saturation, 0.3), l).toColor(),
    s.outline,
  ];
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

