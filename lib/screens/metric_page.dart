// Detail of a daily metric: day / week / month / year, same smooth chart as the stats.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/m3_date_picker.dart';
import '../widgets/period_picker.dart';
import '../widgets/charts.dart';
import '../widgets/health_cards.dart';
import '../widgets/hs_widgets.dart' show isFr, StatBadge, HighlightCard;
import '../widgets/m3_components.dart' show M3SegmentedButton;

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
  int _m = 1; // 0 day, 1 week, 2 month, 3 year
  DateTime? _day; // chosen day (day mode)
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month); // month mode
  int _year = DateTime.now().year; // year mode

  @override
  void initState() {
    super.initState();
    // open on today when it has data, otherwise on the week
    final t = _d(DateTime.now());
    _m = widget.series.any((e) => _d(e.$1) == t) ? 0 : 1;
  }
  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
  static String _k(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _recent() {
    final l = widget.series.reversed.take(7).toList();
    return l.isEmpty ? 0 : l.fold<double>(0, (a, e) => a + e.$2) / l.length;
  }

  Map<String, int> _chart() {
    final today = _d(DateTime.now());
    final byDay = {for (final e in widget.series) _k(_d(e.$1)): e.$2};
    final out = <String, int>{};
    if (_m == 3) { // year: one value per month
      final sums = <String, List<double>>{};
      for (final e in widget.series) {
        if (e.$1.year != _year) continue;
        (sums['${e.$1.year}-${e.$1.month.toString().padLeft(2, '0')}'] ??= []).add(e.$2);
      }
      sums.forEach((k, v) => out[k] = (widget.average ? v.reduce((a, b) => a + b) / v.length : v.reduce((a, b) => a + b)).round());
      return out;
    }
    if (_m == 2) { // month: one value per day of the chosen month
      final last = DateTime(_month.year, _month.month + 1, 0);
      final end = last.isAfter(today) ? today : last;
      for (var d = _month; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
        final v = byDay[_k(d)];
        if (v != null) { out[_k(d)] = v.round(); } else if (!widget.average) { out[_k(d)] = 0; }
      }
      return out;
    }
    final end = _m == 0 ? (_day ?? today) : today;
    final n = _m == 0 ? 14 : 7;
    for (var i = n - 1; i >= 0; i--) {
      final d = DateTime(end.year, end.month, end.day - i), v = byDay[_k(d)];
      if (v != null) { out[_k(d)] = v.round(); } else if (!widget.average) { out[_k(d)] = 0; }
    }
    if (widget.average && out.length < 2) { // sparse data: show the last recorded days instead of an empty chart
      out.clear();
      final l = widget.series.where((e) => !_d(e.$1).isAfter(end)).toList();
      for (final e in l.skip(l.length > 14 ? l.length - 14 : 0)) { out[_k(_d(e.$1))] = e.$2.round(); }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final data = _chart();
    final vals = data.values.where((v) => !widget.average || v > 0).toList();
    final selDay = _day ?? _d(DateTime.now());
    final isToday = selDay == _d(DateTime.now());
    final today = widget.series.where((e) => _d(e.$1) == selDay).fold<double>(0, (a, e) => a + e.$2);
    final first = widget.series.isEmpty ? selDay : _d(widget.series.map((e) => e.$1).reduce((a, b) => a.isBefore(b) ? a : b));
    String dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final total = vals.fold<int>(0, (a, b) => a + b);
    final avg = vals.isEmpty ? 0.0 : total / vals.length;
    final head = _m == 0 ? today : widget.average ? avg : total.toDouble();
    final cap = [isToday ? (isFr ? 'Aujourd\'hui' : 'Today') : dmy(selDay), isFr ? '7 derniers jours' : 'Last 7 days',
        '${monthName(_month.month)} ${_month.year}', '$_year'][_m];
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
            if (_m == 2) PeriodBar(
              label: '${monthName(_month.month)} ${_month.year}',
              onPrev: DateTime(_month.year, _month.month).isAfter(DateTime(first.year, first.month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              onNext: DateTime(_month.year, _month.month).isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
              onPick: () async {
                final d = await showPeriodPicker(context, initial: _month, first: first, last: DateTime.now());
                if (d != null) setState(() => _month = d);
              }),
            if (_m == 3) PeriodBar(
              label: '$_year',
              onPrev: _year > first.year ? () => setState(() => _year--) : null,
              onNext: _year < DateTime.now().year ? () => setState(() => _year++) : null,
              onPick: () async {
                final d = await showPeriodPicker(context, initial: DateTime(_year), first: first, last: DateTime.now(), yearOnly: true);
                if (d != null) setState(() => _year = d.year);
              }),
            if (_m == 0) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                IconButton(onPressed: selDay.isAfter(first) ? () => setState(() => _day = selDay.subtract(const Duration(days: 1))) : null,
                    icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showM3DatePicker(context, initial: selDay, first: first, last: _d(DateTime.now()));
                    if (d != null) setState(() => _day = _d(d));
                  },
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text(dmy(selDay), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)))),
                )),
                IconButton(onPressed: isToday ? null : () => setState(() => _day = selDay.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right_rounded)),
              ]),
            ),
            Row(children: [
              Icon(widget.icon, color: widget.color), const SizedBox(width: 8),
              Text(cap, style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
            ]),
            const SizedBox(height: 4),
            BigValue(widget.fmt(head), widget.unit, caption: _m == 0 || vals.isEmpty ? null
                : widget.average ? (isFr ? 'moyenne' : 'average')
                : '${isFr ? 'moyenne' : 'average'} ${widget.fmt(avg)} ${widget.unit}${_m == 3 ? (isFr ? ' / mois' : ' / month') : (isFr ? ' / jour' : ' / day')}'),
            const SizedBox(height: 14),
            if (vals.isNotEmpty) ...[
              HighlightCard(
                icon: widget.icon, color: widget.color, title: widget.title,
                sentence: widget.verdict != null && showAdviceNotifier.value
                    ? widget.verdict!(widget.average ? avg : _recent(), isFr)
                    : (isFr ? 'Entre ${widget.fmt(vals.reduce((a, b) => a < b ? a : b).toDouble())} et ${widget.fmt(vals.reduce((a, b) => a > b ? a : b).toDouble())} ${widget.unit} sur cette période.'
                            : 'Between ${widget.fmt(vals.reduce((a, b) => a < b ? a : b).toDouble())} and ${widget.fmt(vals.reduce((a, b) => a > b ? a : b).toDouble())} ${widget.unit} over this period.'),
              ),
              const SizedBox(height: 12),
            ],
            if (data.length >= 2) TrendChart(monthly: data, showStats: false, color: widget.color)
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
                Expanded(child: StatBadge(icon: Icons.equalizer_rounded, label: isFr ? 'Moy.' : 'Avg', color: widget.color,
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
