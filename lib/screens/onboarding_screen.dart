// First-run setup: profile (shown at the top of the dashboard afterwards) + Health Connect.
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/skeleton.dart' show M3Spinner;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController(text: profileNameNotifier.value);
  final _h = TextEditingController();
  final _w = TextEditingController();
  DateTime? _birth;
  String _sex = '';
  int _step = 0;
  bool _busy = false;

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  Future<void> _finish() async {
    profileNameNotifier.value = _name.text.trim();
    profileHeightNotifier.value = _num(_h);
    profileWeightNotifier.value = _num(_w);
    profileBirthNotifier.value = _birth == null ? '' : birthToStr(_birth!);
    profileSexNotifier.value = _sex;
    onboardedNotifier.value = true; // main.dart bascule sur HomeScreen
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

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final hs = HealthService.instance;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 24),
          Text('HEALTHSTATS', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: s.primary)),
          const SizedBox(height: 8),
          Text(isFr ? 'Vos stats de santé, réinventées.' : 'Your health stats, reinvented.',
              style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant)),
          const SizedBox(height: 32),
          if (_step == 0) ...[
            Text(isFr ? 'Votre profil' : 'Your profile', style: t.titleLarge),
            const SizedBox(height: 16),
            _field(_name, isFr ? 'Prénom' : 'Name', Icons.person_rounded),
            _field(_h, isFr ? 'Taille (cm)' : 'Height (cm)', Icons.height_rounded, num: true),
            _field(_w, isFr ? 'Poids (kg)' : 'Weight (kg)', Icons.monitor_weight_rounded, num: true),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
              readOnly: true,
              controller: TextEditingController(text: _birth == null ? '' : fmtDay(_birth!)),
              decoration: InputDecoration(labelText: isFr ? 'Date de naissance' : 'Birth date', prefixIcon: const Icon(Icons.cake_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
              onTap: () async {
                final d = await pickBirthDate(context, _birth);
                if (d != null) setState(() => _birth = d);
              },
            )),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'm', label: Text(isFr ? 'Homme' : 'Male')),
                ButtonSegment(value: 'f', label: Text(isFr ? 'Femme' : 'Female')),
                ButtonSegment(value: 'x', label: Text(isFr ? 'Autre' : 'Other')),
              ],
              selected: {if (_sex.isNotEmpty) _sex}, emptySelectionAllowed: true,
              onSelectionChanged: (v) => setState(() => _sex = v.isEmpty ? '' : v.first),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: () => setState(() => _step = 1), child: Text(isFr ? 'Continuer' : 'Continue')),
          ] else ...[
            Text('Google Health (Health Connect)', style: t.titleLarge),
            const SizedBox(height: 12),
            Text(isFr
                ? 'HealthStats lit vos séances, trajets GPS, pas, fréquence cardiaque, sommeil et poids depuis Health Connect. Rien ne quitte votre téléphone.'
                : 'HealthStats reads your workouts, GPS routes, steps, heart rate, sleep and weight from Health Connect. Nothing leaves your phone.',
                style: t.bodyMedium),
            const SizedBox(height: 20),
            if (hs.status == HcStatus.updateRequired)
              Text(isFr ? 'Mettez à jour Health Connect depuis le Play Store.' : 'Update Health Connect from the Play Store.', style: TextStyle(color: s.error)),
            if (hs.status == HcStatus.unavailable)
              Text(isFr ? 'Health Connect est indisponible sur cet appareil.' : 'Health Connect is unavailable on this device.', style: TextStyle(color: s.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy ? SizedBox(width: 22, height: 22, child: M3Spinner(color: s.onPrimary)) : const Icon(Icons.favorite_rounded),
              label: Text(isFr ? 'Autoriser l\'accès' : 'Allow access'),
            ),
            TextButton(onPressed: _finish, child: Text(isFr ? 'Plus tard' : 'Later')),
          ],
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData i, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.name,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(i), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)))),
      );
}
