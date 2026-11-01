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
      final types = {for (final w in hs.workouts) w.type};
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
        M3PageHeader(title: L.navCharts),
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
              child: ChoiceChip(label: Text(_label(m)), selected: _metric == m, onSelected: (_) => setState(() => _metric = m))),
        ])),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(isFr ? 'Tous sports' : 'All sports'), selected: _type == null, onSelected: (_) => setState(() => _type = null))),
          for (final t in types) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(avatar: Icon(sportOf(t).icon, size: 16), label: Text(sportName(sportOf(t))), selected: _type == t, onSelected: (_) => setState(() => _type = t))),
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
      ]));
    });
  }
}

// Listens to locale changes so the page rebuilds.
final Listenable localeNotifierListenable = _LocaleListen();
class _LocaleListen extends ChangeNotifier {
  _LocaleListen() { localeNotifier.addListener(notifyListeners); }
}
