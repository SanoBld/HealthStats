import 'dart:math' as math;
// Small shared HealthStats components (LastStats card style).
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/health_models.dart';
import '../app_state.dart';
import '../services/health_service.dart';
import 'm3_components.dart' show M3Chip, M3CookieBadge, M3PressCard, M3WavyProgress;
import 'm3_date_picker.dart';
import 'skeleton.dart' show M3LoadingIndicator;

bool get isFr => localeNotifier.value == 'fr';
String sportName(SportInfo s) => isFr ? s.fr : s.en;
String fmtDate(DateTime d) {
  final m = isFr
      ? ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.']
      : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
String fmtDay(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
DateTime? parseBirth(String v) => v.isEmpty ? null : DateTime.tryParse(v);
String birthToStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
Future<DateTime?> pickBirthDate(BuildContext c, DateTime? cur) => showM3DatePicker(c,
    initial: cur ?? DateTime(2000, 1, 1), first: DateTime(1920), last: DateTime.now(),
    title: isFr ? 'Date de naissance' : 'Birth date');
/// Colour of a sport. When the "sport colours" option is off, only the accent is used.
Color sportColor(BuildContext c, SportInfo s) =>
    sportColorsNotifier.value ? s.color : Theme.of(c).colorScheme.primary;

/// Icon of the app that wrote a session (falls back to a generic icon).
class AppIcon extends StatelessWidget {
  final String pkg; final double size;
  const AppIcon(this.pkg, {super.key, this.size = 18});
  @override
  Widget build(BuildContext c) {
    final b = HealthService.instance.appIcons[pkg];
    if (b == null) return Icon(Icons.apps_rounded, size: size, color: Theme.of(c).colorScheme.onSurfaceVariant);
    return ClipRRect(borderRadius: BorderRadius.circular(size * 0.25), child: Image.memory(b, width: size, height: size, gaplessPlayback: true));
  }
}

/// Generic yes/no dialog. Returns true only if the user confirms.
Future<bool> confirmDialog(BuildContext c, {required String title, required String message, required String ok, IconData? icon}) async {
  final r = await showDialog<bool>(context: c, builder: (_) => AlertDialog(
    icon: icon == null ? null : Icon(icon), title: Text(title), content: Text(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(isFr ? 'Annuler' : 'Cancel')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
    ]));
  return r == true;
}

/// Asks before deleting the local cache. Returns true if it was cleared.
Future<bool> confirmClearCache(BuildContext c) async {
  final hs = HealthService.instance;
  final size = await hs.cacheSize();
  if (!c.mounted) return false;
  final mb = size < 1024 * 1024 ? '${(size / 1024).round()} KB' : '${(size / 1048576).toStringAsFixed(1)} MB';
  final ok = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text(isFr ? 'Vider le cache ?' : 'Clear the cache?'),
      content: Text(isFr
          ? 'Les activités et tracés enregistrés sur le téléphone ($mb) seront supprimés. Ils seront relus depuis Health Connect à la prochaine synchronisation.'
          : 'Activities and routes saved on the phone ($mb) will be deleted. They will be read again from Health Connect on the next sync.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(isFr ? 'Annuler' : 'Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(isFr ? 'Vider' : 'Clear')),
      ],
    ),
  );
  if (ok != true) return false;
  await hs.clearCache();
  hs.sync();
  return true;
}

/// Big loader (same shape-morph as LastStats) with a wavy progress bar.
class SyncLoader extends StatelessWidget {
  final String text; final double? progress;
  const SyncLoader({super.key, required this.text, this.progress});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const M3LoadingIndicator(size: 72),
          const SizedBox(height: 20),
          Text(text, textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodyMedium),
          const SizedBox(height: 16),
          SizedBox(width: 220, child: M3WavyProgress(value: progress ?? 0.25, height: 14)),
        ]),
      );
}

String distLabel(double m) => unitsMetricNotifier.value
    ? (m < 1000 ? '${m.round()} m' : '${fmtKm(m)} km')
    : (m < 160 ? '${(m * 3.28084).round()} ft' : '${(m / 1609.344).toStringAsFixed(2)} mi');
/// Speed in the user's unit (km/h or mph).
double spdConv(double kmh) => unitsMetricNotifier.value ? kmh : kmh * 0.621371;
String get spdUnit => unitsMetricNotifier.value ? 'km/h' : 'mph';

class SectionTitle extends StatelessWidget {
  final String text; final Widget? trailing; final bool compact;
  const SectionTitle(this.text, {super.key, this.trailing, this.compact = false});
  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.fromLTRB(20, compact ? 10 : 24, 20, compact ? 4 : 8),
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(),
              style: Theme.of(c).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2, color: Theme.of(c).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          ?trailing,
        ]),
      );
}

class StatTile extends StatelessWidget {
  final IconData icon; final String value, label; final Color? color;
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final tint = color ?? s.primary;
    return M3PressCard(
      color: s.surfaceContainer, padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        M3CookieBadge(color: tint.withValues(alpha: 0.18), size: 38, child: Icon(icon, size: 20, color: tint)),
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
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme, sp = w.sport, col = sportColor(c, sp);
    final parts = <String>[
      fmtDuration(w.duration),
      if (w.distanceM > 100) distLabel(w.distanceM),
      if (w.kcal > 0) '${w.kcal.round()} kcal',
      if (sp.strength && w.totalReps > 0) '${w.totalReps} rép.',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: M3PressCard(
            color: s.surfaceContainer, onTap: onTap, padding: const EdgeInsets.all(14),
            child: Row(children: [
              M3CookieBadge(color: col.withValues(alpha: 0.18), size: 48, child: Icon(sp.icon, color: col)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.title.isNotEmpty ? w.title : sportName(sp), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Row(children: [AppIcon(w.source, size: 14), const SizedBox(width: 5), Expanded(child: Text('${fmtDate(w.start)} · ${w.sourceName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)))]),
                const SizedBox(height: 4),
                Text(parts.join(' · '), style: t.bodyMedium),
              ])),
              if (HealthService.instance.tracks[w.id] != null)
                SizedBox(width: 64, height: 44, child: CustomPaint(painter: _ThumbPainter(HealthService.instance.tracks[w.id]!, col)))
              else if (w.hasRoute && !HealthService.instance.isNoTrack(w.id)) Icon(Icons.route_rounded, size: 18, color: s.onSurfaceVariant),
              Icon(Icons.chevron_right_rounded, color: s.onSurfaceVariant),
            ]),
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


/// Line chart you can touch and drag (value + label under the finger, tells the parent where
/// it is). Zoom: pinch with two fingers, +/- buttons, double tap; slider to move when zoomed.
class ScrubChart extends StatefulWidget {
  final List<double> values; final Color color; final String unit; final int decimals; final double height;
  final String Function(int index)? labelOf;
  final void Function(double? fraction)? onScrub;
  const ScrubChart({super.key, required this.values, required this.color, this.unit = '', this.decimals = 0,
      this.height = 200, this.labelOf, this.onScrub});
  @override
  State<ScrubChart> createState() => _ScrubChartState();
}

class _ScrubChartState extends State<ScrubChart> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  @override
  void dispose() { _anim.dispose(); super.dispose(); }
  /// Bucket-average to at most [maxPts] points, then light moving average: no jitter.
  (List<double>, double) _down(List<double> a, int maxPts) {
    var out = a; var step = 1.0;
    if (a.length > maxPts && maxPts > 8) {
      step = a.length / maxPts; out = [];
      for (var k = 0; k < maxPts; k++) {
        final s0 = (k * step).floor(), e0 = ((k + 1) * step).floor().clamp(s0 + 1, a.length);
        var sum = 0.0; for (var i = s0; i < e0; i++) { sum += a[i]; }
        out.add(sum / (e0 - s0));
      }
    }
    if (out.length > 30) {
      final sm = <double>[];
      for (var i = 0; i < out.length; i++) {
        final lo = i < 2 ? 0 : i - 2, hi = i + 2 > out.length - 1 ? out.length - 1 : i + 2;
        var sum = 0.0; for (var k = lo; k <= hi; k++) { sum += out[k]; }
        sm.add(sum / (hi - lo + 1));
      }
      out = sm;
    }
    return (out, step);
  }
  double? _f;                // cursor inside the visible part (0..1)
  double _zoom = 1, _lo = 0; // _lo = start of the visible part (0..1 of all data)
  final Map<int, Offset> _ptr = {};
  double _pd0 = 0, _z0 = 1, _g0 = 0;

  double get _maxZoom { final n = widget.values.length; return n < 40 ? 1.0 : (n / 20).clamp(1.0, 24.0).toDouble(); }
  double _clampLo(double lo, double z) => lo.clamp(0.0, 1 - 1 / z).toDouble();
  double _dist() { final p = _ptr.values.toList(); return (p[0] - p[1]).distance; }

  void _scrub(double? f) {
    if (_ptr.length >= 2) return;
    setState(() => _f = f);
    widget.onScrub?.call(f == null ? null : (_lo + f / _zoom).clamp(0.0, 1.0).toDouble());
  }

  void _zoomBy(double z, double focus) {
    final nz = z.clamp(1.0, _maxZoom).toDouble();
    final g = _lo + focus / _zoom;
    setState(() { _zoom = nz; _lo = _clampLo(g - focus / nz, nz); _f = null; });
  }

  void _reset() => setState(() { _zoom = 1; _lo = 0; _f = null; });

  @override
  void didUpdateWidget(ScrubChart o) {
    super.didUpdateWidget(o);
    if (o.values.length != widget.values.length) { _zoom = 1; _lo = 0; _f = null; _anim.forward(from: 0); }
  }

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    final n = widget.values.length;
    final a = n < 2 ? 0 : (_lo * (n - 1)).floor().clamp(0, n - 1);
    final b = n < 2 ? 0 : ((_lo + 1 / _zoom) * (n - 1)).ceil().clamp(a + 1, n - 1);
    final vis = n < 2 ? widget.values : widget.values.sublist(a, b + 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(s.primaryContainer.withValues(alpha: 0.14), s.surfaceContainer),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(children: [
      LayoutBuilder(builder: (_, box) {
        double frac(Offset p) => ((p.dx - _kPad) / (box.maxWidth - _kPad)).clamp(0.0, 1.0).toDouble();
        return Listener(
          onPointerDown: (e) {
            _ptr[e.pointer] = e.localPosition;
            if (_ptr.length == 2) {
              _pd0 = _dist(); _z0 = _zoom;
              final mid = (_ptr.values.first + _ptr.values.last) / 2;
              _g0 = _lo + frac(mid) / _zoom;
              setState(() => _f = null);
            }
          },
          onPointerMove: (e) {
            _ptr[e.pointer] = e.localPosition;
            if (_ptr.length == 2 && _pd0 > 0 && _maxZoom > 1) {
              final mid = (_ptr.values.first + _ptr.values.last) / 2;
              final nz = (_z0 * _dist() / _pd0).clamp(1.0, _maxZoom).toDouble();
              setState(() { _zoom = nz; _lo = _clampLo(_g0 - frac(mid) / nz, nz); });
            }
          },
          onPointerUp: (e) { _ptr.remove(e.pointer); if (_ptr.length < 2) _pd0 = 0; },
          onPointerCancel: (e) { _ptr.remove(e.pointer); if (_ptr.length < 2) _pd0 = 0; },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _scrub(frac(d.localPosition)),
            onTapUp: (_) => _scrub(null),
            onTapCancel: () => _scrub(null),
            onDoubleTap: () { if (_maxZoom <= 1) return; _zoom > 1 ? _reset() : _zoomBy(3, 0.5); },
            onHorizontalDragStart: (d) => _scrub(frac(d.localPosition)),
            onHorizontalDragUpdate: (d) => _scrub(frac(d.localPosition)),
            onHorizontalDragEnd: (_) => _scrub(null),
            onHorizontalDragCancel: () => _scrub(null),
            child: Builder(builder: (_) {
              final (ds, step) = _down(vis, (box.maxWidth / 3).round());
              return SizedBox(height: widget.height, width: double.infinity, child: AnimatedBuilder(animation: _anim,
                builder: (_, _) => CustomPaint(
                  painter: _ScrubPainter(ds, a, step, Curves.easeOutCubic.transform(_anim.value), widget.color, s.tertiary,
                      s.outlineVariant, s.onSurfaceVariant, s.surface, s.onSurface, _f, widget.unit, widget.decimals, widget.labelOf))));
            }),
          ),
        );
      }),
      if (widget.values.length > 2) Builder(builder: (_) {
        final minVal = widget.values.reduce(math.min);
        final maxVal = widget.values.reduce(math.max);
        final avgVal = widget.values.reduce((a, b) => a + b) / widget.values.length;
        String fmtV(double v) => widget.decimals > 0 ? v.toStringAsFixed(widget.decimals) : v.round().toString();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [
            Expanded(child: StatBadge(icon: Icons.trending_down_rounded, label: 'Min', value: '${fmtV(minVal)} ${widget.unit}', color: s.outline)),
            const SizedBox(width: 8),
            Expanded(child: StatBadge(icon: Icons.equalizer_rounded, label: isFr ? 'Moy.' : 'Avg', value: '${fmtV(avgVal)} ${widget.unit}', color: widget.color)),
            const SizedBox(width: 8),
            Expanded(child: StatBadge(icon: Icons.trending_up_rounded, label: 'Max', value: '${fmtV(maxVal)} ${widget.unit}', color: s.tertiary)),
          ]),
        );
      }),
    ]));
  }
}

/// Same small stat tile everywhere (under every chart).
class StatBadge extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const StatBadge({super.key, required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: s.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.outlineVariant.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 4),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: t.labelSmall?.copyWith(color: s.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Apple Health style card: colored title, one clear sentence, then the data.
class HighlightCard extends StatelessWidget {
  final IconData icon; final String title, sentence; final Color color; final Widget? child;
  const HighlightCard({super.key, required this.icon, required this.title, required this.sentence, required this.color, this.child});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: s.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color), const SizedBox(width: 6),
          Expanded(child: Text(title, style: t.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        Text(sentence, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
        if (child != null) ...[const SizedBox(height: 14), child!],
      ]),
    );
  }
}


const double _kPad = 34;

class _ScrubPainter extends CustomPainter {
  final List<double> v; final int start; final double step, progress;
  final Color color, accent, grid, text, surface, onSurface;
  final double? f; final String unit; final int decimals; final String Function(int)? labelOf;
  _ScrubPainter(this.v, this.start, this.step, this.progress, this.color, this.accent, this.grid, this.text,
      this.surface, this.onSurface, this.f, this.unit, this.decimals, this.labelOf);

  @override
  void paint(Canvas c, Size size) {
    final n = v.length;
    if (n < 2) return;
    var lo = v.reduce(math.min), hi = v.reduce(math.max);
    if (hi - lo < 1) { hi = lo + 1; }
    final pad = (hi - lo) * 0.08; lo -= pad; hi += pad;
    const top = 28.0, bottom = 6.0;
    final w = size.width - _kPad - 8, h = size.height - top - bottom;
    double xAt(int i) => _kPad + w * i / (n - 1);
    double yAt(double val) => top + h * (1 - (val - lo) / (hi - lo));
    for (var k = 0; k < 3; k++) {
      final val = hi - (hi - lo) * k / 2, y = yAt(val);
      c.drawLine(Offset(_kPad, y), Offset(size.width, y), Paint()..color = grid.withValues(alpha: 0.45)..strokeWidth = 1);
      final tp = TextPainter(text: TextSpan(text: val.round().toString(), style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(_kPad - 6 - tp.width, y - tp.height / 2));
    }
    final pts = [for (var i = 0; i < n; i++) Offset(xAt(i), yAt(v[i]))];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[math.max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(i + 2, n - 1)];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy.clamp(top, top + h).toDouble(), c2.dx, c2.dy.clamp(top, top + h).toDouble(), p2.dx, p2.dy);
    }
    c.save();
    c.clipRect(Rect.fromLTRB(_kPad - 6, 0, math.min(size.width, _kPad + w * progress + 6), size.height));
    final fill = Path.from(path)..lineTo(pts.last.dx, top + h)..lineTo(pts.first.dx, top + h)..close();
    c.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.38), accent.withValues(alpha: 0.02)]).createShader(Rect.fromLTWH(_kPad, top, w, h)));
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: [color, accent]).createShader(Rect.fromLTWH(_kPad, top, w, h)));
    c.restore();
    final fi = f;
    if (fi != null) {
      final i = (fi * (n - 1)).round().clamp(0, n - 1);
      final p = pts[i];
      c.drawLine(Offset(p.dx, top), Offset(p.dx, top + h), Paint()..color = accent.withValues(alpha: 0.4)..strokeWidth = 1.5);
      c.drawCircle(p, 8, Paint()..color = surface);
      c.drawCircle(p, 5.5, Paint()..color = accent);
      final label = labelOf?.call(start + (i * step).round());
      final tp = TextPainter(
          text: TextSpan(text: '${v[i].toStringAsFixed(decimals)} $unit${label == null ? '' : '  ·  $label'}',
              style: TextStyle(color: surface, fontSize: 11, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)..layout();
      final bw = tp.width + 18, bh = tp.height + 10;
      final bx = (p.dx - bw / 2).clamp(0.0, size.width - bw).toDouble();
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, 0, bw, bh), const Radius.circular(12)), Paint()..color = onSurface);
      tp.paint(c, Offset(bx + 9, 5));
    }
  }

  @override
  bool shouldRepaint(_ScrubPainter o) => o.f != f || o.v != v || o.color != color || o.start != start || o.progress != progress;
}


// ── Filters with many choices: one chip that opens a searchable list ──
class FilterEntry {
  final String key, label; final IconData? icon; final int count; final Widget? leading;
  const FilterEntry(this.key, this.label, this.count, [this.icon, this.leading]);
}

/// Returns the chosen key, '' for "all", or null if closed.
Future<String?> pickFilter(BuildContext c, {required String title, required String allLabel,
    required List<FilterEntry> entries, String? current}) {
  return showModalBottomSheet<String>(
    context: c, isScrollControlled: true, showDragHandle: true,
    builder: (_) => _FilterSheet(title: title, allLabel: allLabel, entries: entries, current: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final String title, allLabel; final List<FilterEntry> entries; final String? current;
  const _FilterSheet({required this.title, required this.allLabel, required this.entries, this.current});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _q = '';
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    final list = widget.entries.where((e) => e.label.toLowerCase().contains(_q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(c).size.height * 0.7, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Row(children: [
          Expanded(child: Text(widget.title, style: Theme.of(c).textTheme.titleLarge)),
        ])),
        if (widget.entries.length > 6) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: isFr ? 'Rechercher' : 'Search',
              filled: true, fillColor: s.surfaceContainerHigh, border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none)),
        )),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
          if (_q.isEmpty) _tile(c, '', widget.allLabel, null, null, null),
          for (final e in list) _tile(c, e.key, e.label, e.icon, e.count, e.leading),
          if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(isFr ? 'Aucun résultat' : 'No result'))),
        ])),
      ])),
    );
  }

  Widget _tile(BuildContext c, String key, String label, IconData? icon, int? count, Widget? leading) {
    final s = Theme.of(c).colorScheme;
    final sel = (widget.current ?? '') == key;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(sel ? 24 : 14)),
      tileColor: sel ? s.primaryContainer : null,
      leading: leading ?? (icon == null ? null : Icon(icon)),
      title: Text(label, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      trailing: count == null ? null : Text('$count', style: Theme.of(c).textTheme.labelLarge?.copyWith(color: s.onSurfaceVariant)),
      onTap: () => Navigator.pop(c, key),
    ));
  }
}

/// One chip showing the current choice; tap = open the list.
class FilterChipButton extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const FilterChipButton({super.key, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
      child: M3Chip(label: Text('$label  ▾'), selected: active, onSelected: (_) => onTap()));
}


/// Tiny drawing of a GPS route (for the activity list).
class _ThumbPainter extends CustomPainter {
  final List<LatLng> pts; final Color color;
  _ThumbPainter(this.pts, this.color);
  @override
  void paint(Canvas c, Size size) {
    if (pts.length < 2) return;
    var minLa = pts.first.latitude, maxLa = minLa, minLo = pts.first.longitude, maxLo = minLo;
    for (final p in pts) {
      if (p.latitude < minLa) minLa = p.latitude;
      if (p.latitude > maxLa) maxLa = p.latitude;
      if (p.longitude < minLo) minLo = p.longitude;
      if (p.longitude > maxLo) maxLo = p.longitude;
    }
    final dLa = (maxLa - minLa).abs() < 1e-9 ? 1e-9 : maxLa - minLa, dLo = (maxLo - minLo).abs() < 1e-9 ? 1e-9 : maxLo - minLo;
    final k = ((size.width - 6) / dLo) < ((size.height - 6) / dLa) ? (size.width - 6) / dLo : (size.height - 6) / dLa;
    final ox = (size.width - dLo * k) / 2, oy = (size.height - dLa * k) / 2;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = ox + (pts[i].longitude - minLo) * k, y = size.height - oy - (pts[i].latitude - minLa) * k;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    c.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_ThumbPainter o) => o.pts != pts || o.color != color;
}

/// Action row that asks for confirmation INSIDE the row (animated), no popup.
class InlineConfirm extends StatefulWidget {
  final IconData icon; final String title, message, okLabel; final String? subtitle; final bool danger;
  final Future<void> Function() onConfirm;
  const InlineConfirm({super.key, required this.icon, required this.title, required this.message, required this.okLabel,
      this.subtitle, this.danger = false, required this.onConfirm});
  @override
  State<InlineConfirm> createState() => _InlineConfirmState();
}

class _InlineConfirmState extends State<InlineConfirm> {
  bool _open = false, _busy = false;
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    final col = widget.danger ? s.error : s.primary;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: AnimatedContainer(
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic,
      decoration: BoxDecoration(color: _open ? col.withValues(alpha: 0.12) : s.surfaceContainer, borderRadius: BorderRadius.circular(_open ? 24 : 16)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
        child: Column(children: [
          ListTile(
            leading: Icon(widget.icon, color: widget.danger ? s.error : null),
            title: Text(widget.title, style: TextStyle(color: widget.danger ? s.error : null)),
            subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
            trailing: AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 320), child: const Icon(Icons.expand_more_rounded)),
            onTap: _busy ? null : () => setState(() => _open = !_open)),
          if (_open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.message, style: Theme.of(c).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _busy ? null : () => setState(() => _open = false), child: Text(isFr ? 'Annuler' : 'Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                style: widget.danger ? FilledButton.styleFrom(backgroundColor: s.error, foregroundColor: s.onError) : null,
                onPressed: _busy ? null : () async {
                  setState(() => _busy = true);
                  await widget.onConfirm();
                  if (mounted) setState(() { _busy = false; _open = false; });
                },
                child: _busy ? const SizedBox(width: 18, height: 18, child: M3LoadingIndicator(size: 18)) : Text(widget.okLabel)),
            ]),
          ])),
        ]),
      ),
    ));
  }
}

/// Row that turns into a number field inside the row (animated), no popup.
class InlineNumberTile extends StatefulWidget {
  final IconData icon; final String title, unit; final double value; final void Function(double) onSave;
  const InlineNumberTile({super.key, required this.icon, required this.title, required this.unit, required this.value, required this.onSave});
  @override
  State<InlineNumberTile> createState() => _InlineNumberTileState();
}

class _InlineNumberTileState extends State<InlineNumberTile> {
  bool _open = false;
  late final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  String _txt(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: AnimatedContainer(
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic,
      decoration: BoxDecoration(color: _open ? s.primaryContainer.withValues(alpha: 0.5) : s.surfaceContainer, borderRadius: BorderRadius.circular(_open ? 24 : 16)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
        child: Column(children: [
          ListTile(
            leading: Icon(widget.icon), title: Text(widget.title),
            subtitle: Text(widget.value > 0 ? '${_txt(widget.value)} ${widget.unit}' : (isFr ? 'Non renseigné' : 'Not set')),
            trailing: AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 320), child: const Icon(Icons.expand_more_rounded)),
            onTap: () => setState(() { _open = !_open; if (_open) _ctrl.text = widget.value > 0 ? _txt(widget.value) : ''; })),
          if (_open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(suffixText: widget.unit, filled: true, fillColor: s.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
            const SizedBox(width: 10),
            FilledButton(onPressed: () {
              final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
              if (v != null) widget.onSave(v);
              setState(() => _open = false);
            }, child: Text(isFr ? 'OK' : 'OK')),
          ])),
        ]),
      ),
    ));
  }
}


/// Inline banner asking for a missing Health Connect permission (no popup of ours).
class PermPrompt extends StatefulWidget {
  final String perm, text; final IconData icon; final VoidCallback? onGranted;
  const PermPrompt({super.key, required this.perm, required this.text, this.icon = Icons.lock_open_rounded, this.onGranted});
  @override
  State<PermPrompt> createState() => _PermPromptState();
}

class _PermPromptState extends State<PermPrompt> {
  bool _busy = false;
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, hs = HealthService.instance;
    return ListenableBuilder(listenable: hs, builder: (_, _) => AnimatedSize(
      duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
      child: hs.hasPerm(widget.perm) ? const SizedBox(width: double.infinity) : Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: s.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(widget.icon, color: s.tertiary), const SizedBox(width: 12),
          Expanded(child: Text(widget.text, style: TextStyle(color: s.onTertiaryContainer))),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              final ok = await hs.ensurePerm(widget.perm);
              if (mounted) setState(() => _busy = false);
              if (ok) widget.onGranted?.call();
            },
            child: Text(isFr ? 'Autoriser' : 'Allow')),
        ]),
      ),
    ));
  }
}
