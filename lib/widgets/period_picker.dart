// Month / year chooser (small dialog) used by the charts of every data page.
import 'package:flutter/material.dart';
import 'hs_widgets.dart' show isFr;

const _frM = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _enM = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthName(int m) => (isFr ? _frM : _enM)[m - 1];

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
  @override
  Widget build(BuildContext c) {
    final s = Theme.of(c).colorScheme, t = Theme.of(c).textTheme;
    final f = widget.first, l = widget.last;
    return AlertDialog(
      backgroundColor: s.surfaceContainerHigh,
      title: widget.yearOnly
          ? Text(isFr ? 'Choisir l\'année' : 'Choose a year')
          : Row(children: [
              IconButton(onPressed: _y > f.year ? () => setState(() => _y--) : null, icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Center(child: Text('$_y', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)))),
              IconButton(onPressed: _y < l.year ? () => setState(() => _y++) : null, icon: const Icon(Icons.chevron_right_rounded)),
            ]),
      content: SizedBox(width: 320, child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (widget.yearOnly)
          for (var y = l.year; y >= f.year; y--)
            ChoiceChip(label: Text('$y'), selected: y == widget.initial.year, onSelected: (_) => Navigator.pop(c, DateTime(y)))
        else
          for (var m = 1; m <= 12; m++)
            ChoiceChip(
              label: Text(monthName(m)),
              selected: _y == widget.initial.year && m == widget.initial.month,
              onSelected: DateTime(_y, m).isBefore(DateTime(f.year, f.month)) || DateTime(_y, m).isAfter(DateTime(l.year, l.month))
                  ? null : (_) => Navigator.pop(c, DateTime(_y, m))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isFr ? 'Annuler' : 'Cancel'))],
    );
  }
}

/// Row with arrows and a button that opens the month / year chooser.
class PeriodBar extends StatelessWidget {
  final String label; final VoidCallback? onPrev, onNext; final VoidCallback onPick;
  const PeriodBar({super.key, required this.label, required this.onPrev, required this.onNext, required this.onPick});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: FilledButton.tonalIcon(
              onPressed: onPick, icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(label[0].toUpperCase() + label.substring(1)))),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      );
}
