// First-run flow: welcome, profile, body, goals, look and Health Connect, one question per page.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3Spinner;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 6;
  final _name = TextEditingController(text: profileNameNotifier.value);
  final _h = TextEditingController();
  final _w = TextEditingController();
  DateTime? _birth;
  String _sex = '';
  int _step = 0;
  bool _busy = false, _forward = true;

  static const _accents = [0xFFFF2020, 0xFFFF6D00, 0xFFFFB300, 0xFF2E9E5B, 0xFF00A6A6, 0xFF1E6CF0, 0xFF7C4DFF, 0xFFE91E8C, 0xFF607D8B];

  @override
  void dispose() { _name.dispose(); _h.dispose(); _w.dispose(); super.dispose(); }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  void _go(int d) => setState(() { _forward = d > 0; _step = (_step + d).clamp(0, _steps - 1); });

  Future<void> _finish() async {
    profileNameNotifier.value = _name.text.trim();
    profileHeightNotifier.value = _num(_h);
    profileWeightNotifier.value = _num(_w);
    profileBirthNotifier.value = _birth == null ? '' : birthToStr(_birth!);
    profileSexNotifier.value = _sex;
    onboardedNotifier.value = true; // main.dart switches to HomeScreen
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final hs = HealthService.instance;
    try {
      await hs.refreshStatus();
      if (hs.status == HcStatus.available) await hs.requestPermissions();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (hs.permitted) { _finish(); }
  }

  bool get _canNext => switch (_step) { 1 => _name.text.trim().isNotEmpty, _ => true };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // progress + back
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(children: [
              AnimatedOpacity(
                opacity: _step > 0 ? 1 : 0, duration: const Duration(milliseconds: 200),
                child: IconButton(onPressed: _step > 0 ? () => _go(-1) : null, icon: const Icon(Icons.arrow_back_rounded))),
              Expanded(child: TweenAnimationBuilder<double>(
                tween: Tween(end: (_step + 1) / _steps), duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic,
                builder: (_, v, _) => ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: s.surfaceContainerHighest)))),
            ]),
          ),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
                child: SlideTransition(position: Tween(begin: Offset(_forward ? 0.08 : -0.08, 0), end: Offset.zero).animate(anim), child: child)),
            child: KeyedSubtree(key: ValueKey(_step), child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: _page(s, t))),
          )),
          if (_step < _steps - 1)
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 20), child: SizedBox(width: double.infinity, height: 56,
              child: FilledButton(onPressed: _canNext ? () => _go(1) : null,
                  child: Text(_step == 0 ? (isFr ? 'Commencer' : 'Get started') : (isFr ? 'Continuer' : 'Continue'))))),
        ]),
      ),
    );
  }

  Widget _title(String big, String sub) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(big, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(sub, style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant, height: 1.35)),
      const SizedBox(height: 28),
    ]);
  }

  List<Widget> _page(ColorScheme s, TextTheme t) {
    switch (_step) {
      case 0:
        return [
          const SizedBox(height: 40),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1), duration: const Duration(milliseconds: 700), curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(width: 104, height: 104, decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(34)),
                child: Icon(Icons.favorite_rounded, size: 54, color: s.primary)),
          ),
          const SizedBox(height: 32),
          Text('HealthStats', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: s.primary)),
          const SizedBox(height: 10),
          Text(isFr ? 'Toutes vos données de santé, au même endroit.' : 'All your health data in one place.',
              style: t.titleMedium?.copyWith(color: s.onSurfaceVariant)),
          const SizedBox(height: 28),
          for (final e in [
            (Icons.fitness_center_rounded, isFr ? 'Séances, trajets et records' : 'Workouts, routes and records'),
            (Icons.bedtime_rounded, isFr ? 'Sommeil, cœur et récupération' : 'Sleep, heart and recovery'),
            (Icons.lock_rounded, isFr ? 'Tout reste sur votre téléphone' : 'Everything stays on your phone'),
          ]) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: s.secondaryContainer, shape: BoxShape.circle), child: Icon(e.$1, size: 20, color: s.onSecondaryContainer)),
            const SizedBox(width: 14), Expanded(child: Text(e.$2, style: t.bodyLarge)),
          ])),
        ];
      case 1:
        return [
          _title(isFr ? 'Comment vous appelez-vous ?' : 'What should we call you?', isFr ? 'Votre prénom s\'affiche en haut du tableau de bord.' : 'Your name is shown at the top of the dashboard.'),
          _field(_name, isFr ? 'Prénom' : 'Name', Icons.person_rounded, onChanged: (_) => setState(() {})),
        ];
      case 2:
        return [
          _title(isFr ? 'Quelques infos sur vous' : 'A bit about you', isFr ? 'Elles servent à estimer les calories et à situer vos résultats. Tout est facultatif.' : 'Used to estimate calories and put your results in context. All optional.'),
          Row(children: [
            Expanded(child: _field(_h, isFr ? 'Taille (cm)' : 'Height (cm)', Icons.height_rounded, num: true)),
            const SizedBox(width: 12),
            Expanded(child: _field(_w, isFr ? 'Poids (kg)' : 'Weight (kg)', Icons.monitor_weight_rounded, num: true)),
          ]),
          Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(
            readOnly: true,
            controller: TextEditingController(text: _birth == null ? '' : fmtDay(_birth!)),
            decoration: InputDecoration(labelText: isFr ? 'Date de naissance' : 'Birth date', prefixIcon: const Icon(Icons.cake_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
            onTap: () async {
              final d = await pickBirthDate(context, _birth);
              if (d != null) setState(() => _birth = d);
            },
          )),
          Text(isFr ? 'Sexe' : 'Sex', style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final e in [('m', isFr ? 'Homme' : 'Male'), ('f', isFr ? 'Femme' : 'Female'), ('x', isFr ? 'Autre' : 'Other')])
              M3Chip(label: Text(e.$2), selected: _sex == e.$1, onSelected: (_) => setState(() => _sex = _sex == e.$1 ? '' : e.$1)),
          ]),
        ];
      case 3:
        return [
          _title(isFr ? 'Vos objectifs' : 'Your goals', isFr ? 'Vous pourrez les changer à tout moment dans les réglages.' : 'You can change them any time in settings.'),
          Text(isFr ? 'Pas par jour' : 'Steps per day', style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in [5000, 7500, 10000, 12500, 15000])
              M3Chip(label: Text('$v'), selected: stepGoalNotifier.value == v, onSelected: (_) => setState(() => stepGoalNotifier.value = v)),
          ]),
          const SizedBox(height: 24),
          Text(isFr ? 'Séances par semaine' : 'Workouts per week', style: t.labelLarge?.copyWith(color: s.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var v = 1; v <= 7; v++)
              M3Chip(label: Text('$v'), selected: weeklyGoalNotifier.value == v, onSelected: (_) => setState(() => weeklyGoalNotifier.value = v)),
          ]),
        ];
      case 4:
        return [
          _title(isFr ? 'Votre style' : 'Your style', isFr ? 'Choisissez l\'apparence et ce que vous voulez voir.' : 'Pick the look and what you want to see.'),
          M3SegmentedButton<int>(
            segments: [ButtonSegment(value: 0, label: Text(isFr ? 'Système' : 'System')), ButtonSegment(value: 1, label: Text(isFr ? 'Clair' : 'Light')), ButtonSegment(value: 2, label: Text(isFr ? 'Sombre' : 'Dark'))],
            selected: {themeModeNotifier.value.index}, onSelectionChanged: (v) => setState(() => themeModeNotifier.value = ThemeMode.values[v.first])),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(isFr ? 'Couleurs dynamiques (fond d\'écran)' : 'Dynamic colors (wallpaper)'),
              value: useDynamicColorNotifier.value, onChanged: (v) => setState(() => useDynamicColorNotifier.value = v)),
          if (!useDynamicColorNotifier.value) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final c in _accents) GestureDetector(
                onTap: () => setState(() => accentNotifier.value = Color(c)),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 44, height: 44,
                    decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle,
                        border: Border.all(color: accentNotifier.value.toARGB32() == c ? s.onSurface : Colors.transparent, width: 3)),
                    child: accentNotifier.value.toARGB32() == c ? const Icon(Icons.check_rounded, color: Colors.white) : null)),
            ]),
          ],
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(isFr ? 'Afficher les conseils' : 'Show advice'),
              value: showAdviceNotifier.value, onChanged: (v) => setState(() => showAdviceNotifier.value = v)),
        ];
      default:
        final hs = HealthService.instance;
        return [
          _title('Health Connect', isFr
              ? 'HealthStats lit vos séances, trajets GPS, pas, fréquence cardiaque, sommeil et poids. Rien ne quitte votre téléphone.'
              : 'HealthStats reads your workouts, GPS routes, steps, heart rate, sleep and weight. Nothing leaves your phone.'),
          if (hs.status == HcStatus.updateRequired)
            Text(isFr ? 'Mettez à jour Health Connect depuis le Play Store.' : 'Update Health Connect from the Play Store.', style: TextStyle(color: s.error)),
          if (hs.status == HcStatus.unavailable)
            Text(isFr ? 'Health Connect est indisponible sur cet appareil.' : 'Health Connect is unavailable on this device.', style: TextStyle(color: s.error)),
          const SizedBox(height: 12),
          SizedBox(height: 56, child: FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy ? SizedBox(width: 22, height: 22, child: M3Spinner(color: s.onPrimary)) : const Icon(Icons.favorite_rounded),
            label: Text(isFr ? 'Autoriser l\'accès' : 'Allow access'))),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: _finish, child: Text(isFr ? 'Plus tard' : 'Later'))),
        ];
    }
  }

  Widget _field(TextEditingController c, String label, IconData i, {bool num = false, ValueChanged<String>? onChanged}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(controller: c, onChanged: onChanged, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.name,
            textCapitalization: num ? TextCapitalization.none : TextCapitalization.words,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(i), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
      );
}
