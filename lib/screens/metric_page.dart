// Detail of a daily metric: day / week / month / year, same smooth chart as the stats.
import 'package:flutter/material.dart';
import '../widgets/charts.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart' show isFr;
import '../widgets/m3_components.dart' show M3SegmentedButton;

class MetricPage extends StatefulWidget {
  final String title, unit; final IconData icon; final Color color;
  final List<(DateTime, double)> series; // one value per day
  final bool average;                    // true = averaged (heart rate), false = summed
  final String Function(double) fmt;
  final String Function(double avg, bool isFr)? verdict; // short sentence: good or not
  const MetricPage({super.key, required this.title, required this.unit, required this.icon, required this.color,
      required this.series, required this.fmt, this.average = false, this.verdict});
  @override
  State<MetricPage> createState() => _MetricPageState();
}

class _MetricPageState extends State<MetricPage> {
  int _m = 1; // 0 day, 1 week, 2 month, 3 year
  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
  static String _k(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, int> _chart() {
    final now = _d(DateTime.now());
    final byDay = {for (final e in widget.series) _k(_d(e.$1)): e.$2};
    final out = <String, int>{};
    if (_m == 3) {
      final sums = <String, List<double>>{};
      for (final e in widget.series) {
        if (now.difference(_d(e.$1)).inDays > 365) continue;
        (sums['${e.$1.year}-${e.$1.month.toString().padLeft(2, '0')}'] ??= []).add(e.$2);
      }
      sums.forEach((k, v) => out[k] = (widget.average ? v.reduce((a, b) => a + b) / v.length : v.reduce((a, b) => a + b)).round());
      return out;
    }
    final n = _m == 0 ? 14 : _m == 1 ? 7 : 30;
    for (var i = n - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i)), v = byDay[_k(d)];
      if (v != null) { out[_k(d)] = v.round(); } else if (!widget.average) { out[_k(d)] = 0; }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final data = _chart();
    final vals = data.values.where((v) => !widget.average || v > 0).toList();
    final today = widget.series.where((e) => _d(e.$1) == _d(DateTime.now())).fold<double>(0, (a, e) => a + e.$2);
    final total = vals.fold<int>(0, (a, b) => a + b);
    final avg = vals.isEmpty ? 0.0 : total / vals.length;
    final head = _m == 0 ? today : widget.average ? avg : total.toDouble();
    final cap = [isFr ? 'Aujourd\'hui' : 'Today', isFr ? '7 derniers jours' : 'Last 7 days',
        isFr ? '30 derniers jours' : 'Last 30 days', isFr ? '12 derniers mois' : 'Last 12 months'][_m];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: M3SegmentedButton<int>(
            segments: [for (final (i, l) in [isFr ? 'Jour' : 'Day', isFr ? 'Semaine' : 'Week', isFr ? 'Mois' : 'Month', isFr ? 'Année' : 'Year'].indexed)
              ButtonSegment(value: i, label: Text(l))],
            selected: {_m}, onSelectionChanged: (v) => setState(() => _m = v.first)),
        ),
        Divider(height: 1, thickness: 1, color: s.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
            Row(children: [
              Icon(widget.icon, color: widget.color), const SizedBox(width: 8),
              Text(cap, style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
            ]),
            const SizedBox(height: 4),
            BigValue(widget.fmt(head), widget.unit, caption: _m == 0 || vals.isEmpty ? null
                : widget.average ? (isFr ? 'moyenne' : 'average')
                : '${isFr ? 'moyenne' : 'average'} ${widget.fmt(avg)} ${widget.unit}${_m == 3 ? (isFr ? ' / mois' : ' / month') : (isFr ? ' / jour' : ' / day')}'),
            const SizedBox(height: 14),
            if (data.length >= 2) TrendChart(monthly: data, showStats: false, color: widget.color)
            else Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(isFr ? 'Pas assez de données' : 'Not enough data'))),
            if (widget.average && vals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: s.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: s.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  for (final e in [
                    (isFr ? 'Min' : 'Min', vals.reduce((a, b) => a < b ? a : b)),
                    (isFr ? 'Moy.' : 'Avg', avg.round()),
                    (isFr ? 'Max' : 'Max', vals.reduce((a, b) => a > b ? a : b)),
                  ]) Expanded(child: Column(children: [
                    Text(e.$1, style: t.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('${e.$2} ${widget.unit}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: widget.color)),
                  ])),
                ]),
              ),
              if (widget.verdict != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(widget.verdict!(avg, isFr), style: t.bodyMedium?.copyWith(height: 1.35)),
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}
