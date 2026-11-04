// Detail of a daily metric: day / week / month / year, same smooth chart as the stats.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/period_picker.dart';
import '../widgets/charts.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart' show isFr, StatBadge, HighlightCard;

class MetricPage extends StatefulWidget {
  final String title, unit; final IconData icon; final Color color;
  final List<(DateTime, double)> series; // one value per day
  final bool average;                    // true = averaged (heart rate), false = summed
  final String Function(double) fmt;
  final String? desc; // what this metric is
  final String Function(double avg, bool isFr)? verdict; // short sentence: good or not
  const MetricPage({super.key, required this.title, required this.unit, required this.icon, required this.color,
      required this.series, required this.fmt, this.average = false, this.verdict, this.desc});
  @override
  State<MetricPage> createState() => _MetricPageState();
}

class _MetricPageState extends State<MetricPage> {
  final PeriodSel _sel = PeriodSel();

  @override
  void initState() {
    super.initState();
    // open on today when it has data, otherwise on the week
    final t = dayOnly(DateTime.now());
    _sel.mode = widget.series.any((e) => dayOnly(e.$1) == t) ? 0 : 1;
  }
  static String _k(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _recent() {
    final l = widget.series.reversed.take(7).toList();
    return l.isEmpty ? 0 : l.fold<double>(0, (a, e) => a + e.$2) / l.length;
  }

  Map<String, int> _chart() {
    final today = dayOnly(DateTime.now());
    final byDay = {for (final e in widget.series) _k(dayOnly(e.$1)): e.$2};
    final out = <String, int>{};
    if (_sel.mode == 3) { // year: one value per month
      final sums = <String, List<double>>{};
      for (final e in widget.series) {
        if (e.$1.year != _sel.anchor.year) continue;
        (sums['${e.$1.year}-${e.$1.month.toString().padLeft(2, '0')}'] ??= []).add(e.$2);
      }
      sums.forEach((k, v) => out[k] = (widget.average ? v.reduce((a, b) => a + b) / v.length : v.reduce((a, b) => a + b)).round());
      return out;
    }
    // day: the 14 days ending on the chosen day (context); week / month: the whole period
    final DateTime from = _sel.mode == 0 ? _sel.anchor.subtract(const Duration(days: 13)) : _sel.start;
    final DateTime to = _sel.end.isAfter(today) ? today : _sel.end;
    for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      final v = byDay[_k(d)];
      if (v != null) { out[_k(d)] = v.round(); } else if (!widget.average) { out[_k(d)] = 0; }
    }
    if (_sel.mode == 0 && widget.average && out.length < 2) { // sparse data: last recorded days instead of an empty chart
      out.clear();
      final l = widget.series.where((e) => !dayOnly(e.$1).isAfter(_sel.anchor)).toList();
      for (final e in l.skip(l.length > 14 ? l.length - 14 : 0)) { out[_k(dayOnly(e.$1))] = e.$2.round(); }
    }
    return out;
  }

  /// Same value as the headline, for the period before the chosen one.
  double? _previous() {
    final p = PeriodSel(mode: _sel.mode, anchor: _sel.anchor)..shift(-1);
    // an unfinished period is compared with the same number of days of the previous one
    final today = dayOnly(DateTime.now());
    final elapsed = _sel.isCurrent && _sel.mode > 0 ? today.difference(_sel.start).inDays : null;
    final cut = elapsed == null ? null : p.start.add(Duration(days: elapsed));
    final l = [for (final e in widget.series) if (p.contains(e.$1) && (cut == null || !dayOnly(e.$1).isAfter(cut))) e.$2];
    if (l.isEmpty) return null;
    final sum = l.fold<double>(0, (a, b) => a + b);
    return _sel.mode == 0 ? sum : widget.average ? sum / l.length : sum;
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final data = _chart();
    final vals = (_sel.mode == 0
            ? data.entries.where((e) => e.key == _k(_sel.anchor)).map((e) => e.value)
            : data.values).where((v) => !widget.average || v > 0).toList();
    final dayVal = widget.series.where((e) => dayOnly(e.$1) == _sel.anchor).fold<double>(0, (a, e) => a + e.$2);
    final first = widget.series.isEmpty ? _sel.anchor : dayOnly(widget.series.map((e) => e.$1).reduce((a, b) => a.isBefore(b) ? a : b));
    final total = vals.fold<int>(0, (a, b) => a + b);
    final avg = vals.isEmpty ? 0.0 : total / vals.length;
    final head = _sel.mode == 0 ? dayVal : widget.average ? avg : total.toDouble();
    final last = dayOnly(DateTime.now());
    final chartVals = data.values.where((v) => !widget.average || v > 0).toList();
    final shownVals = _sel.mode == 0 ? chartVals : vals;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: PeriodModeBar(sel: _sel, changed: () => setState(() {}))),
        Divider(height: 1, thickness: 1, color: s.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
            PeriodNav(sel: _sel, first: first, last: last, changed: () => setState(() {})),
            Row(children: [
              Icon(widget.icon, color: widget.color), const SizedBox(width: 8),
              Expanded(child: Text(_sel.caption, style: t.labelLarge?.copyWith(color: s.onSurfaceVariant))),
            ]),
            const SizedBox(height: 4),
            BigValue(widget.fmt(head), widget.unit, caption: _sel.mode == 0 || vals.isEmpty ? null
                : widget.average ? (isFr ? 'moyenne' : 'average')
                : '${isFr ? 'moyenne' : 'average'} ${widget.fmt(avg)} ${widget.unit}${_sel.mode == 3 ? (isFr ? ' / mois' : ' / month') : (isFr ? ' / jour' : ' / day')}'),
            Builder(builder: (_) {
              final prev = _previous();
              if (prev == null || prev == 0 || head == 0) return const SizedBox.shrink();
              final pct = ((head - prev) / prev * 100).round();
              final what = [isFr ? 'la veille' : 'the day before', isFr ? 'la semaine précédente' : 'the previous week',
                  isFr ? 'le mois précédent' : 'the previous month', isFr ? 'l\'année précédente' : 'the previous year'][_sel.mode];
              return Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                Icon(pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: widget.color),
                const SizedBox(width: 6),
                Expanded(child: Text(isFr ? '${pct >= 0 ? '+' : ''}$pct % par rapport à $what' : '${pct >= 0 ? '+' : ''}$pct% versus $what',
                    style: t.labelLarge?.copyWith(color: s.onSurfaceVariant))),
              ]));
            }),
            const SizedBox(height: 14),
            if (shownVals.isNotEmpty) ...[
              HighlightCard(
                icon: widget.icon, color: widget.color, title: widget.title,
                sentence: widget.verdict != null && showAdviceNotifier.value
                    ? widget.verdict!(widget.average ? avg : _recent(), isFr)
                    : (isFr ? 'Entre ${widget.fmt(shownVals.reduce((a, b) => a < b ? a : b).toDouble())} et ${widget.fmt(shownVals.reduce((a, b) => a > b ? a : b).toDouble())} ${widget.unit} sur cette période.'
                            : 'Between ${widget.fmt(shownVals.reduce((a, b) => a < b ? a : b).toDouble())} and ${widget.fmt(shownVals.reduce((a, b) => a > b ? a : b).toDouble())} ${widget.unit} over this period.'),
              ),
              const SizedBox(height: 12),
            ],
            if (data.length >= 2) TrendChart(key: ValueKey('${_sel.mode}${_sel.start}'), monthly: data, showStats: false, color: widget.color)
            else Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(isFr ? 'Pas assez de données' : 'Not enough data'))),
            if (vals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: widget.average
                    ? StatBadge(icon: Icons.trending_down_rounded, label: 'Min', color: s.outline,
                        value: '${widget.fmt(vals.reduce((a, b) => a < b ? a : b).toDouble())} ${widget.unit}')
                    : StatBadge(icon: Icons.functions_rounded, label: 'Total', color: s.outline,
                        value: '${widget.fmt(total.toDouble())} ${widget.unit}')),
                const SizedBox(width: 8),
                Expanded(child: StatBadge(icon: Icons.equalizer_rounded, label: isFr ? 'Moyenne' : 'Average', color: widget.color,
                    value: '${widget.fmt(avg)} ${widget.unit}')),
                const SizedBox(width: 8),
                Expanded(child: StatBadge(icon: Icons.trending_up_rounded, label: 'Max', color: s.tertiary,
                    value: '${widget.fmt(vals.reduce((a, b) => a > b ? a : b).toDouble())} ${widget.unit}')),
              ]),
            ],
            if (widget.desc != null) ...[
              const SizedBox(height: 16),
              Text(widget.desc!, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.35)),
            ],
          ]),
        ),
      ]),
    );
  }
}
