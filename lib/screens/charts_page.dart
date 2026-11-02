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
  late final Future<List<(DateTime, double)>> _sleep = HealthService.instance.sleepNights();

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

      return SafeArea(child: Column(children: [
        M3PageHeader(showBack: false, title: L.navCharts),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: M3SegmentedButton<_Period>(
          segments: [
            ButtonSegment(value: _Period.day, label: Text(isFr ? 'Jour' : 'Day')),
            ButtonSegment(value: _Period.week, label: Text(isFr ? 'Semaine' : 'Week')),
            ButtonSegment(value: _Period.month, label: Text(isFr ? 'Mois' : 'Month')),
          ],
          selected: {_period}, onSelectionChanged: (v) => setState(() => _period = v.first),
        )),
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [
          for (final m in _Metric.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: M3Chip(label: Text(_label(m)), selected: _metric == m, onSelected: (_) => setState(() => _metric = m))),
        ])),
        SizedBox(height: 46, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
          FilterChipButton(
            label: _type == null ? (isFr ? 'Tous les sports' : 'All sports') : sportName(sportOf(_type!)),
            active: _type != null,
            onTap: () async {
              final counts = <int, int>{};
              for (final w in hs.workouts) { counts[w.type] = (counts[w.type] ?? 0) + 1; }
              final sorted = counts.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
              final r = await pickFilter(ctx, title: isFr ? 'Sport' : 'Sport', allLabel: isFr ? 'Tous les sports' : 'All sports',
                  entries: [for (final e in sorted) FilterEntry('${e.key}', sportName(sportOf(e.key)), e.value, sportOf(e.key).icon)],
                  current: _type?.toString());
              if (r != null) setState(() => _type = r.isEmpty ? null : int.parse(r));
            },
          ),
        ])),
        Divider(height: 1, thickness: 1, color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.3)),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 32), children: [
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
          ]),
        ),
      ]));
    });
  }
}

class _MetricSpec {
  final String kind, perm, fr, en, unit; final int dec;
  const _MetricSpec(this.kind, this.perm, this.fr, this.en, this.unit, [this.dec = 0]);
}
const _extra = [
  _MetricSpec('restingHr', 'READ_RESTING_HEART_RATE', 'FC au repos', 'Resting heart rate', 'bpm'),
  _MetricSpec('hrv', 'READ_HEART_RATE_VARIABILITY', 'Variabilité cardiaque (HRV)', 'Heart rate variability (HRV)', 'ms'),
  _MetricSpec('spo2', 'READ_OXYGEN_SATURATION', 'Oxygène dans le sang (SpO₂)', 'Blood oxygen (SpO₂)', '%', 1),
  _MetricSpec('vo2', 'READ_VO2_MAX', 'VO₂ max', 'VO₂ max', 'ml/kg/min', 1),
  _MetricSpec('resp', 'READ_RESPIRATORY_RATE', 'Respiration', 'Respiratory rate', '/min', 1),
  _MetricSpec('bodyFat', 'READ_BODY_FAT', 'Masse grasse', 'Body fat', '%', 1),
  _MetricSpec('systolic', 'READ_BLOOD_PRESSURE', 'Tension (systolique)', 'Blood pressure (systolic)', 'mmHg'),
  _MetricSpec('temp', 'READ_BODY_TEMPERATURE', 'Température', 'Body temperature', '°C', 1),
];

/// One optional chart: shown when there is data; if the permission is missing, asks for it right here.
class _MetricChart extends StatefulWidget {
  final _MetricSpec spec; final String Function(DateTime) label; final Color color;
  const _MetricChart({required this.spec, required this.label, required this.color});
  @override
  State<_MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<_MetricChart> {
  late Future<List<(DateTime, double)>> _f = HealthService.instance.metric(widget.spec.kind);
  @override
  Widget build(BuildContext c) {
    final m = widget.spec, hs = HealthService.instance;
    return ListenableBuilder(listenable: hs, builder: (_, _) {
      if (!hs.hasPerm(m.perm)) {
        // only offer it once the rest is connected
        if (!hs.permitted) return const SizedBox.shrink();
        return PermPrompt(perm: m.perm, icon: Icons.show_chart_rounded, onGranted: () => setState(() => _f = hs.metric(m.kind)),
            text: isFr ? 'Autorise « ${m.fr} » pour afficher ce graphe.' : 'Allow “${m.en}” to show this chart.');
      }
      return FutureBuilder<List<(DateTime, double)>>(future: _f, builder: (_, snap) {
        final d = snap.data ?? const <(DateTime, double)>[];
        if (d.length < 2) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(isFr ? m.fr : m.en),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: d.map((e) => e.$2).toList(), color: widget.color, unit: m.unit, decimals: m.dec, labelOf: (i) => widget.label(d[i].$1))),
        ]);
      });
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
      for (final m in _extra) _MetricChart(spec: m, label: lab, color: p),
      FutureBuilder<List<(DateTime, double)>>(future: _sleep, builder: (_, snap) {
        final sl = (snap.data ?? const <(DateTime, double)>[]).where((e) => e.$2 > 0.5).toList();
        if (sl.length < 2) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(isFr ? 'Sommeil par nuit (90 j)' : 'Sleep per night (90d)'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: sl.map((e) => e.$2).toList(), color: p, unit: 'h', decimals: 1, labelOf: (i) => lab(sl[i].$1))),
        ]);
      }),
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
