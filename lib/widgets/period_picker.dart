// Period selection shared by every data page: day / week / month / year.
// One model (PeriodSel), one navigation bar (PeriodNav) and an M3 month/year
// dialog whose cells all have the same size (same style as the calendar).
import 'package:flutter/material.dart';
import '../theme/m3_motion.dart';
import 'hs_widgets.dart' show isFr;
import 'm3_components.dart';
import 'm3_date_picker.dart';

const _frM = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _enM = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _frD = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _enD = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String monthName(int m) => (isFr ? _frM : _enM)[m - 1];
String weekdayName(int wd) => (isFr ? _frD : _enD)[wd - 1];
DateTime dayOnly(DateTime x) => DateTime(x.year, x.month, x.day);
DateTime mondayOf(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));
String _dn(int d) => isFr && d == 1 ? '1er' : '$d';

/// Full date, never shortened: « mercredi 4 novembre 2026 ».
String fullDate(DateTime d, {bool weekday = true}) => isFr
    ? '${weekday ? '${weekdayName(d.weekday)} ' : ''}${_dn(d.day)} ${monthName(d.month)} ${d.year}'
    : '${weekday ? '${weekdayName(d.weekday)}, ' : ''}${monthName(d.month)} ${d.day}, ${d.year}';

/// Chosen period: mode 0 day, 1 week (Mon-Sun), 2 month, 3 year.
class PeriodSel {
  int mode;
  DateTime anchor;
  PeriodSel({this.mode = 1, DateTime? anchor}) : anchor = dayOnly(anchor ?? DateTime.now());

  DateTime get start => switch (mode) {
        0 => anchor,
        1 => mondayOf(anchor),
        2 => DateTime(anchor.year, anchor.month, 1),
        _ => DateTime(anchor.year, 1, 1),
      };
  DateTime get end => switch (mode) {
        0 => anchor,
        1 => mondayOf(anchor).add(const Duration(days: 6)),
        2 => DateTime(anchor.year, anchor.month + 1, 0),
        _ => DateTime(anchor.year, 12, 31),
      };
  bool contains(DateTime d) { final x = dayOnly(d); return !x.isBefore(start) && !x.isAfter(end); }
  bool get isCurrent => contains(DateTime.now());

  /// Same cell of the previous / next period.
  void shift(int delta) {
    anchor = switch (mode) {
      0 => anchor.add(Duration(days: delta)),
      1 => anchor.add(Duration(days: 7 * delta)),
      2 => DateTime(anchor.year, anchor.month + delta, 1),
      _ => DateTime(anchor.year + delta, 1, 1),
    };
  }
  bool canPrev(DateTime first) => start.isAfter(dayOnly(first));
  bool canNext(DateTime last) => end.isBefore(dayOnly(last));

  String get label {
    final s = start, e = end;
    switch (mode) {
      case 0: return fullDate(s);
      case 1:
        if (isFr) {
          final a = s.month == e.month && s.year == e.year ? _dn(s.day) : '${_dn(s.day)} ${monthName(s.month)}${s.year != e.year ? ' ${s.year}' : ''}';
          return 'Du $a au ${_dn(e.day)} ${monthName(e.month)} ${e.year}';
        }
        return '${monthName(s.month)} ${s.day} – ${s.month == e.month ? '' : '${monthName(e.month)} '}${e.day}, ${e.year}';
      case 2: return '${monthName(s.month)} ${s.year}';
      default: return '${s.year}';
    }
  }
  String get caption => switch (mode) {
        0 => isCurrent ? (isFr ? 'Aujourd\'hui' : 'Today') : label,
        1 => isCurrent ? (isFr ? 'Cette semaine' : 'This week') : label,
        2 => isCurrent ? (isFr ? 'Ce mois-ci' : 'This month') : label,
        _ => isCurrent ? (isFr ? 'Cette année' : 'This year') : label,
      };
}

/// Opens the right chooser: calendar for day / week, month grid for month, year grid for year.
Future<void> pickPeriod(BuildContext c, PeriodSel sel, {required DateTime first, required DateTime last, required VoidCallback changed}) async {
  final f = dayOnly(first), l = dayOnly(last);
  final init = sel.anchor.isBefore(f) ? f : sel.anchor.isAfter(l) ? l : sel.anchor;
  if (sel.mode <= 1) {
    final d = await showM3DatePicker(c, initial: init, first: f, last: l,
        title: sel.mode == 1 ? (isFr ? 'Un jour de la semaine' : 'Any day of the week') : null);
    if (d != null) { sel.anchor = dayOnly(d); changed(); }
  } else {
    final d = await showPeriodPicker(c, initial: init, first: f, last: l, yearOnly: sel.mode == 3);
    if (d != null) { sel.anchor = d; changed(); }
  }
}

/// yearOnly = false: returns the first day of the chosen month. yearOnly = true: returns Jan 1 of the year.
Future<DateTime?> showPeriodPicker(BuildContext c,
        {required DateTime initial, required DateTime first, required DateTime last, bool yearOnly = false}) =>
    showDialog<DateTime>(context: c, builder: (_) => _PeriodDialog(initial: initial, first: first, last: last, yearOnly: yearOnly));

class _PeriodDialog extends StatefulWidget {
  final DateTime initial, first, last; final bool yearOnly;
  const _PeriodDialog({required this.initial, required this.first, required this.last, required this.yearOnly});
  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late int _y = widget.initial.year;
  late final int _selM = widget.initial.month;
  late final int _selY = widget.initial.year;
  bool _yearsOpen = false;

  bool _monthOk(int y, int m) {
    final d = DateTime(y, m);
    return !d.isBefore(DateTime(widget.first.year, widget.first.month)) && !d.isAfter(DateTime(widget.last.year, widget.last.month));
  }

  // The 12 most recent years that fit the 3 x 4 grid.
  List<int> get _years {
    final from = (widget.last.year - 11) < widget.first.year ? widget.first.year : widget.last.year - 11;
    return [for (var y = from; y <= widget.last.year; y++) y];
  }

  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final f = widget.first, l = widget.last;
    final showYears = widget.yearOnly || _yearsOpen;
    final headline = widget.yearOnly ? '$_selY' : '${monthName(_selM)} $_selY';
    return Dialog(
      backgroundColor: s.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((widget.yearOnly ? (isFr ? 'Année' : 'Year') : (isFr ? 'Mois' : 'Month')).toUpperCase(),
                    style: t.labelSmall?.copyWith(color: s.onPrimaryContainer.withValues(alpha: 0.75), fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(headline[0].toUpperCase() + headline.substring(1),
                    style: t.headlineSmall?.copyWith(color: s.onPrimaryContainer, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 14),
            if (!widget.yearOnly) ...[
              Row(children: [
                M3TonalButton(width: 44, height: 44, padding: EdgeInsets.zero, radius: BorderRadius.circular(22), color: s.secondaryContainer,
                    onTap: _y > f.year && !_yearsOpen ? () => setState(() => _y--) : null,
                    child: Icon(Icons.chevron_left_rounded, color: s.onSecondaryContainer)),
                Expanded(child: Center(child: M3Chip(
                    selected: _yearsOpen,
                    avatar: Icon(_yearsOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    label: Text('$_y'),
                    onSelected: (_) => setState(() => _yearsOpen = !_yearsOpen)))),
                M3TonalButton(width: 44, height: 44, padding: EdgeInsets.zero, radius: BorderRadius.circular(22), color: s.secondaryContainer,
                    onTap: _y < l.year && !_yearsOpen ? () => setState(() => _y++) : null,
                    child: Icon(Icons.chevron_right_rounded, color: s.onSecondaryContainer)),
              ]),
              const SizedBox(height: 12),
            ],
            // Fixed height: same dialog size for months and for years.
            SizedBox(
              height: 4 * 52 + 3 * 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: showYears
                    ? KeyedSubtree(key: const ValueKey('y'), child: _grid<int>(
                        _years, (y) => '$y', (y) => y == (widget.yearOnly ? _selY : _y), (y) => true,
                        (y) {
                          m3Haptic();
                          if (widget.yearOnly) { Navigator.pop(c, DateTime(y)); } else { setState(() { _y = y; _yearsOpen = false; }); }
                        }))
                    : KeyedSubtree(key: const ValueKey('m'), child: _grid<int>(
                        [for (var m = 1; m <= 12; m++) m], monthName,
                        (m) => _y == _selY && m == _selM, (m) => _monthOk(_y, m),
                        (m) { m3Haptic(); Navigator.pop(c, DateTime(_y, m)); })),
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              M3LabelButton(kind: M3ButtonKind.text, height: 44, label: isFr ? 'Annuler' : 'Cancel', onTap: () => Navigator.pop(c)),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Equal-size cells, 3 columns x 4 rows.
  Widget _grid<T>(List<T> items, String Function(T) label, bool Function(T) selected, bool Function(T) enabled, void Function(T) onTap) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
      crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 52,
      children: [
        for (final it in items)
          _PeriodCell(text: label(it), selected: selected(it), enabled: enabled(it), s: s, t: t, onTap: () => onTap(it)),
      ],
    );
  }
}

class _PeriodCell extends StatelessWidget {
  final String text; final bool selected, enabled; final ColorScheme s; final TextTheme t; final VoidCallback onTap;
  const _PeriodCell({required this.text, required this.selected, required this.enabled, required this.s, required this.t, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final fg = selected ? s.onPrimary : enabled ? s.onSurface : s.onSurface.withValues(alpha: 0.3);
    final r = BorderRadius.circular(selected ? 26 : 16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? s.primary : s.primaryContainer.withValues(alpha: enabled ? 0.55 : 0.2), borderRadius: r),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r, onTap: enabled ? onTap : null,
          child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: FittedBox(fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, style: t.labelLarge?.copyWith(color: fg, fontWeight: selected ? FontWeight.w800 : FontWeight.w600))))),
        ),
      ),
    );
  }
}

/// Same bar for day, week, month and year: arrow, button that opens the chooser, arrow.
class PeriodNav extends StatelessWidget {
  final PeriodSel sel; final DateTime first, last; final VoidCallback changed;
  const PeriodNav({super.key, required this.sel, required this.first, required this.last, required this.changed});
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    Widget arrow(IconData i, VoidCallback? on) => M3TonalButton(
        width: 44, height: 44, padding: EdgeInsets.zero, radius: BorderRadius.circular(22), color: s.secondaryContainer,
        onTap: on, child: Icon(i, color: s.onSecondaryContainer));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        arrow(Icons.chevron_left_rounded, sel.canPrev(first) ? () { sel.shift(-1); changed(); } : null),
        const SizedBox(width: 8),
        Expanded(child: M3TonalButton(
          height: 44, radius: BorderRadius.circular(22), color: s.primaryContainer,
          onTap: () => pickPeriod(c, sel, first: first, last: last, changed: changed),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.calendar_month_rounded, size: 18, color: s.onPrimaryContainer), const SizedBox(width: 8),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(sel.label[0].toUpperCase() + sel.label.substring(1), maxLines: 1,
                style: t.labelLarge?.copyWith(color: s.onPrimaryContainer, fontWeight: FontWeight.w800)))),
          ]),
        )),
        const SizedBox(width: 8),
        arrow(Icons.chevron_right_rounded, sel.canNext(last) ? () { sel.shift(1); changed(); } : null),
      ]),
    );
  }
}

/// Day / week / month / year selector (same segments everywhere).
class PeriodModeBar extends StatelessWidget {
  final PeriodSel sel; final VoidCallback changed;
  const PeriodModeBar({super.key, required this.sel, required this.changed});
  @override
  Widget build(BuildContext c) => M3SegmentedButton<int>(
        segments: [for (final (i, l) in [isFr ? 'Jour' : 'Day', isFr ? 'Semaine' : 'Week', isFr ? 'Mois' : 'Month', isFr ? 'Année' : 'Year'].indexed)
          ButtonSegment(value: i, label: Text(l))],
        selected: {sel.mode}, onSelectionChanged: (v) { sel.mode = v.first; changed(); });
}
