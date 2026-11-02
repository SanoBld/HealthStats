// Charts tab: same visuals as LastStats (zoomable trend, weekdays,
// donut), fed by Health Connect workouts.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/charts.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';

enum _Metric { sessions, minutes, distance, kcal, steps }
enum _Period { day, week, month }

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  _Metric _metric = _Metric.minutes;
  _Period _period = _Period.week;
  int? _type;
  late final Future<List<(DateTime, double)>> _weights = HealthService.instance.weights();

  String _label(_Metric m) => switch (m) {
        _Metric.sessions => isFr ? 'Séances' : 'Workouts',
        _Metric.minutes => isFr ? 'Durée (min)' : 'Duration (min)',
        _Metric.distance => 'Distance (km)',
        _Metric.kcal => 'kcal',
        _Metric.steps => isFr ? 'Pas' : 'Steps',
      };

  String _k2(int n) => n.toString().padLeft(2, '0');
  String _day(DateTime d) => '${d.year}-${_k2(d.month)}-${_k2(d.day)}';
  DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  int _val(Workout w) => switch (_metric) {
        _Metric.sessions => 1,
        _Metric.minutes => w.duration.inMinutes,
        _Metric.distance => (w.distanceM / 1000).round(),
        _Metric.kcal => w.kcal.round(),
        _Metric.steps => w.steps,
      };

  String _bucket(DateTime d) => switch (_period) {
        _Period.day => _day(d),
        _Period.week => _day(_monday(d)),
        _Period.month => '${d.year}-${_k2(d.month)}',
      };

  Map<String, int> _series(HealthService hs, List<Workout> ws) {
    final now = DateTime.now();
    final keys = <String>[];
    switch (_period) {
      case _Period.day:
        for (var i = 29; i >= 0; i--) { keys.add(_day(now.subtract(Duration(days: i)))); }
      case _Period.week:
        for (var i = 11; i >= 0; i--) { keys.add(_day(_monday(now).subtract(Duration(days: 7 * i)))); }
      case _Period.month:
        for (var i = 11; i >= 0; i--) { final d = DateTime(now.year, now.month - i, 1); keys.add('${d.year}-${_k2(d.month)}'); }
    }
    final out = {for (final k in keys) k: 0};
    if (_metric == _Metric.steps && _type == null) {
      for (final d in hs.days) { final k = _bucket(d.day); if (out.containsKey(k)) out[k] = out[k]! + d.steps; }
    } else {
      for (final w in ws) { final k = _bucket(w.start); if (out.containsKey(k)) out[k] = out[k]! + _val(w); }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(listenable: Listenable.merge([hs, localeNotifierListenable]), builder: (ctx, _) {
      final ws = hs.workouts.where((w) => _type == null || w.type == _type).toList();
      final series = _series(hs, ws);
      // By weekday (last 12 weeks)
      final lim = DateTime.now().subtract(const Duration(days: 84));
      final byDay = {for (var d = 1; d <= 7; d++) d: 0};
      for (final w in ws.where((w) => w.start.isAfter(lim))) { byDay[w.start.weekday] = byDay[w.start.weekday]! + _val(w); }
      // Share by sport (duration, 30 days)
      final per = <int, int>{};
      for (final w in hs.workouts.where((w) => w.start.isAfter(DateTime.now().subtract(const Duration(days: 30))))) {
        per[w.type] = (per[w.type] ?? 0) + w.duration.inMinutes;
      }
      final share = per.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      return SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        M3PageHeader(showBack: false, title: L.navCharts),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: M3SegmentedButton<_Period>(
          segments: [
            ButtonSegment(value: _Period.day, label: Text(isFr ? 'Jour' : 'Day')),
            ButtonSegment(value: _Period.week, label: Text(isFr ? 'Semaine' : 'Week')),
            ButtonSegment(value: _Period.month, label: Text(isFr ? 'Mois' : 'Month')),
          ],
          selected: {_period}, onSelectionChanged: (v) => setState(() => _period = v.first),
        )),
        SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
          for (final m in _Metric.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: M3Chip(label: Text(_label(m)), selected: _metric == m, onSelected: (_) => setState(() => _metric = m))),
        ])),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          FilterChipButton(
            label: _type == null ? (isFr ? 'Tous sports' : 'All sports') : sportName(sportOf(_type!)),
            active: _type != null,
            onTap: () async {
              final counts = <int, int>{};
              for (final w in hs.workouts) { counts[w.type] = (counts[w.type] ?? 0) + 1; }
              final sorted = counts.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
              final r = await pickFilter(ctx, title: 'Sport', allLabel: isFr ? 'Tous sports' : 'All sports',
                  entries: [for (final e in sorted) FilterEntry('${e.key}', sportName(sportOf(e.key)), e.value, sportOf(e.key).icon)],
                  current: _type?.toString());
              if (r != null) setState(() => _type = r.isEmpty ? null : int.parse(r));
            },
          ),
        ])),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TrendChart(key: ValueKey('$_period$_metric$_type'), monthly: series)),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: WeekChart(data: byDay)),
        if (share.isNotEmpty && _type == null) ...[
          SectionTitle(isFr ? 'Répartition (30 j, durée)' : 'Share (30d, duration)'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ShareDonut(
            items: share, getLabel: (e) => sportName(sportOf((e as MapEntry<int, int>).key)),
            getPlays: (e) => (e as MapEntry<int, int>).value)),
        ],
        ..._trends(hs),
      ]));
    });
  }
}

extension _Trends on _ChartsPageState {
  /// Touchable daily curves: heart rate, steps, weight (drag a finger to read each day).
  List<Widget> _trends(HealthService hs) {
    final lim = DateTime.now().subtract(const Duration(days: 90));
    final d90 = hs.days.where((d) => d.day.isAfter(lim)).toList();
    final hr = d90.where((d) => d.hrAvg > 0).toList();
    final st = d90.where((d) => d.steps > 0).toList();
    String lab(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final p = Theme.of(context).colorScheme.primary;
    return [
      if (hr.length > 1) ...[
        SectionTitle(isFr ? 'Fréquence cardiaque moyenne (90 j)' : 'Average heart rate (90d)'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
            values: hr.map((d) => d.hrAvg).toList(), color: p, unit: 'bpm', labelOf: (i) => lab(hr[i].day))),
      ],
      if (st.length > 1) ...[
        SectionTitle(isFr ? 'Pas par jour (90 j)' : 'Steps per day (90d)'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
            values: st.map((d) => d.steps.toDouble()).toList(), color: p, unit: isFr ? 'pas' : 'steps', labelOf: (i) => lab(st[i].day))),
      ],
      FutureBuilder<List<(DateTime, double)>>(future: _weights, builder: (_, snap) {
        final w = snap.data ?? const <(DateTime, double)>[];
        if (w.length < 2) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(isFr ? 'Poids' : 'Weight'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: w.map((e) => e.$2).toList(), color: p, unit: 'kg', decimals: 1, labelOf: (i) => lab(w[i].$1))),
        ]);
      }),
    ];
  }
}

// Listens to locale changes so the page rebuilds.
final Listenable localeNotifierListenable = _LocaleListen();
class _LocaleListen extends ChangeNotifier {
  _LocaleListen() { localeNotifier.addListener(notifyListeners); }
}
