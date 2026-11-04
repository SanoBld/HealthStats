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
import '../widgets/period_picker.dart';

enum _Metric { sessions, minutes, distance, kcal, steps }

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  _Metric _metric = _Metric.minutes;
  final PeriodSel _sel = PeriodSel(mode: 1);
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

  int _val(Workout w) => switch (_metric) {
        _Metric.sessions => 1,
        _Metric.minutes => w.duration.inMinutes,
        _Metric.distance => (w.distanceM / 1000).round(),
        _Metric.kcal => w.kcal.round(),
        _Metric.steps => w.steps,
      };

  /// Fixed window = the chosen period. Day: 24 hours, week / month: days, year: months.
  String _bucket(DateTime d) => switch (_sel.mode) {
        0 => '${_k2(d.hour)}h',
        1 || 2 => _day(d),
        _ => '${d.year}-${_k2(d.month)}',
      };

  Map<String, int> _series(HealthService hs, List<Workout> ws) {
    final keys = <String>[];
    final today = dayOnly(DateTime.now());
    switch (_sel.mode) {
      case 0: for (var h = 0; h < 24; h++) { keys.add('${_k2(h)}h'); }
      case 1 || 2:
        for (var d = _sel.start; !d.isAfter(_sel.end); d = DateTime(d.year, d.month, d.day + 1)) { if (!d.isAfter(today)) keys.add(_day(d)); }
      default: for (var m = 1; m <= 12; m++) { keys.add('${_sel.anchor.year}-${_k2(m)}'); }
    }
    final out = {for (final k in keys) k: 0};
    if (_metric == _Metric.steps && _type == null) {
      if (_sel.mode == 0) return out; // steps are only known per day
      for (final d in hs.days) { if (!_sel.contains(d.day)) continue; final k = _bucket(d.day); if (out.containsKey(k)) out[k] = out[k]! + d.steps; }
    } else {
      for (final w in ws) { if (!_sel.contains(w.start)) continue; final k = _bucket(w.start); if (out.containsKey(k)) out[k] = out[k]! + _val(w); }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(listenable: Listenable.merge([hs, localeNotifierListenable]), builder: (ctx, _) {
      final ws = hs.workouts.where((w) => _type == null || w.type == _type).toList();
      final inP = ws.where((w) => _sel.contains(w.start)).toList();
      final series = _series(hs, ws);
      // By weekday, inside the period
      final byDay = {for (var d = 1; d <= 7; d++) d: 0};
      for (final w in inP) { byDay[w.start.weekday] = byDay[w.start.weekday]! + _val(w); }
      // Share by sport (duration) inside the period
      final per = <int, int>{}, perKcal = <int, int>{};
      for (final w in hs.workouts.where((w) => _sel.contains(w.start))) {
        per[w.type] = (per[w.type] ?? 0) + w.duration.inMinutes;
        perKcal[w.type] = (perKcal[w.type] ?? 0) + w.kcal.round();
      }
      final share = per.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      final shareK = perKcal.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      final first = hs.workouts.isEmpty ? dayOnly(DateTime.now()) : dayOnly(hs.workouts.map((w) => w.start).reduce((a, b) => a.isBefore(b) ? a : b));
      final p = Theme.of(ctx).colorScheme;

      return SafeArea(child: ListView(children: [
        M3PageHeader(showBack: false, title: L.navCharts),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: PeriodModeBar(sel: _sel, changed: () => setState(() {}))),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PeriodNav(sel: _sel, first: first, last: dayOnly(DateTime.now()), changed: () => setState(() {}))),
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
        Divider(height: 1, thickness: 1, color: p.outlineVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TrendChart(key: ValueKey('${_sel.mode}${_sel.start}$_metric$_type'), monthly: series)),
        if (_sel.mode != 0) ...[
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: WeekChart(data: byDay)),
        ],
        if (share.isNotEmpty && _type == null) ...[
          SectionTitle(isFr ? 'Répartition par sport (durée)' : 'Share by sport (duration)'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ShareDonut(
            items: share, getLabel: (e) => sportName(sportOf((e as MapEntry<int, int>).key)),
            getPlays: (e) => (e as MapEntry<int, int>).value)),
        ],
        if (shareK.isNotEmpty && _type == null) ...[
          SectionTitle(isFr ? 'Calories par sport' : 'Calories by sport'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ShareDonut(
            items: shareK, getLabel: (e) => sportName(sportOf((e as MapEntry<int, int>).key)),
            getPlays: (e) => (e as MapEntry<int, int>).value)),
        ],
        ..._workoutCharts(inP),
        ..._trends(hs),
        const SizedBox(height: 32),
      ]));
    });
  }
}

extension _WorkoutCharts on _ChartsPageState {
  String _lab(DateTime d) => fullDate(d, weekday: false);
  /// Per-workout curves inside the period: pace, speed, energy used, intensity.
  List<Widget> _workoutCharts(List<Workout> inP) {
    final p = Theme.of(context).colorScheme.primary;
    final sorted = [...inP]..sort((a, b) => a.start.compareTo(b.start));
    final pace = sorted.where((w) => w.paceMinKm != null && w.paceMinKm! < 20).toList();
    final kcal = sorted.where((w) => w.kcal > 0).toList();
    final hr = sorted.where((w) => w.hrAvg > 0).toList();
    final dist = sorted.where((w) => w.distanceM > 100).toList();
    final eff = sorted.where((w) => w.speedKmh != null && w.hrAvg > 60 && w.distanceM >= 1000 && w.type != 8 && w.type != 9).toList();
    String lab(Workout w) => '${_lab(w.start)} · ${sportName(w.sport)}';
    Widget chart(String title, List<double> v, String unit, String Function(int) l, {int dec = 0}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(title),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(values: v, color: p, unit: unit, decimals: dec, labelOf: l)),
        ]);
    final totalKcal = sorted.fold<double>(0, (a, w) => a + w.kcal);
    final days = (_sel.end.difference(_sel.start).inDays + 1).clamp(1, 366);
    return [
      if (pace.length > 1) chart(isFr ? 'Allure par séance (min/km)' : 'Pace per workout (min/km)', [for (final w in pace) w.paceMinKm!], 'min/km', (i) => lab(pace[i]), dec: 1),
      if (dist.length > 1) chart(isFr ? 'Distance par séance' : 'Distance per workout', [for (final w in dist) w.distanceM / 1000], 'km', (i) => lab(dist[i]), dec: 1),
      if (eff.length > 1) chart(isFr ? 'Efficacité aérobie (vitesse ÷ FC, plus haut = mieux)' : 'Aerobic efficiency (speed ÷ HR, higher is better)',
          [for (final w in eff) w.speedKmh! * 1000 / 60 / w.hrAvg * 100], '', (i) => lab(eff[i]), dec: 1),
      if (kcal.length > 1) chart(isFr ? 'Calories par séance' : 'Calories per workout', [for (final w in kcal) w.kcal], 'kcal', (i) => lab(kcal[i])),
      if (hr.length > 1) chart(isFr ? 'Intensité : FC moyenne par séance' : 'Intensity: average heart rate per workout', [for (final w in hr) w.hrAvg], 'bpm', (i) => lab(hr[i])),
      if (totalKcal > 0) Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Row(children: [
        Expanded(child: StatBadge(icon: Icons.local_fire_department_rounded, label: isFr ? 'Total' : 'Total', color: p, value: '${totalKcal.round()} kcal')),
        const SizedBox(width: 8),
        Expanded(child: StatBadge(icon: Icons.today_rounded, label: isFr ? 'Moyenne par jour' : 'Average per day', color: p, value: '${(totalKcal / days).round()} kcal')),
        const SizedBox(width: 8),
        Expanded(child: StatBadge(icon: Icons.fitness_center_rounded, label: isFr ? 'Par séance' : 'Per workout', color: p, value: '${(totalKcal / sorted.length).round()} kcal')),
      ])),
    ];
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
  final List<(DateTime, double)> Function(List<(DateTime, double)>) win;
  const _MetricChart({required this.spec, required this.label, required this.color, required this.win});
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
        final d = widget.win(snap.data ?? const <(DateTime, double)>[]);
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
  /// Period window for sparse series: inside the period, or the 14 last values before its end when the period is a single day.
  List<(DateTime, double)> _win(List<(DateTime, double)> l) {
    final inside = l.where((e) => _sel.contains(e.$1)).toList();
    if (inside.length >= 2 || _sel.mode != 0) return inside;
    final before = l.where((e) => !dayOnly(e.$1).isAfter(_sel.end)).toList();
    return before.skip(before.length > 14 ? before.length - 14 : 0).toList();
  }

  /// Touchable daily curves on the chosen period: heart rate, steps, sleep, weight and the optional metrics.
  List<Widget> _trends(HealthService hs) {
    final hr = _win([for (final d in hs.days) if (d.hrAvg > 0) (d.day, d.hrAvg)]);
    final st = _win([for (final d in hs.days) if (d.steps > 0) (d.day, d.steps.toDouble())]);
    String lab(DateTime d) => fullDate(d, weekday: false);
    final p = Theme.of(context).colorScheme.primary;
    return [
      if (hr.length > 1) ...[
        SectionTitle(isFr ? 'Fréquence cardiaque moyenne' : 'Average heart rate'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
            values: hr.map((d) => d.$2).toList(), color: p, unit: 'bpm', labelOf: (i) => lab(hr[i].$1))),
      ],
      if (st.length > 1) ...[
        SectionTitle(isFr ? 'Pas par jour' : 'Steps per day'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
            values: st.map((d) => d.$2).toList(), color: p, unit: isFr ? 'pas' : 'steps', labelOf: (i) => lab(st[i].$1))),
      ],
      for (final m in _extra) _MetricChart(spec: m, label: lab, color: p, win: _win),
      FutureBuilder<List<(DateTime, double)>>(future: _sleep, builder: (_, snap) {
        final sl = _win((snap.data ?? const <(DateTime, double)>[]).where((e) => e.$2 > 0.5).toList());
        if (sl.length < 2) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(isFr ? 'Sommeil par nuit' : 'Sleep per night'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ScrubChart(
              values: sl.map((e) => e.$2).toList(), color: p, unit: 'h', decimals: 1, labelOf: (i) => lab(sl[i].$1))),
        ]);
      }),
      FutureBuilder<List<(DateTime, double)>>(future: _weights, builder: (_, snap) {
        final w = _win(snap.data ?? const <(DateTime, double)>[]);
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
