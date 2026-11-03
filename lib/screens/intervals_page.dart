// Intervals.icu: free personal API key → activities, GPS routes and heart rate (no Health Connect consent).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/health_service.dart';
import '../services/intervals_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3LoadingIndicator;
import 'settings/settings_helpers.dart';
import 'settings/settings_rows.dart';

class IntervalsPage extends StatefulWidget {
  const IntervalsPage({super.key});
  @override
  State<IntervalsPage> createState() => _IntervalsPageState();
}

class _IntervalsPageState extends State<IntervalsPage> {
  final _key = TextEditingController(), _id = TextEditingController(text: '0');
  bool _connected = false, _confirm = false;
  DateTime? _last;
  bool _checking = false; String? _okName, _checkErr;

  @override
  void initState() {
    super.initState();
    IntervalsService.credentials().then((c) async {
      final l = await IntervalsService.lastSync();
      if (!mounted) return;
      setState(() { _connected = c != null; _last = l; if (c != null) { _key.text = c.$1; _id.text = c.$2; } });
      if (c != null) _verify();
    });
  }

  @override
  void dispose() { _key.dispose(); _id.dispose(); super.dispose(); }

  Future<void> _verify() async {
    setState(() { _checking = true; _checkErr = null; });
    final r = await IntervalsService.check(_key.text.trim(), _id.text.trim().isEmpty ? '0' : _id.text.trim(), isFr);
    if (mounted) setState(() { _checking = false; _okName = r.$2; _checkErr = r.$1 ? null : r.$3; });
  }

  Future<void> _connect() async {
    if (_key.text.trim().isEmpty) return;
    await IntervalsService.save(_key.text, _id.text);
    setState(() => _connected = true);
    _verify();
    final ok = await HealthService.instance.syncIntervals();
    final l = await IntervalsService.lastSync();
    if (mounted) setState(() { _last = l; if (!ok && HealthService.instance.intervalsError != null) _connected = true; });
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance, s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(child: ListenableBuilder(listenable: hs, builder: (ctx, _) {
        final r = hs.intervalsResult;
        return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          M3PageHeader(title: 'Intervals.icu', subtitle: _connected ? (isFr ? 'Connecté' : 'Connected') : null),
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: Text(
              isFr ? 'Service gratuit qui récupère tes sorties depuis ta montre ou ton app de sport. HealthStats lit tes activités, ton cœur et tes tracés GPS : '
                     'la carte n’a plus besoin d’autorisation Health Connect.'
                   : 'Free service that collects your workouts from your watch or sports app. HealthStats reads your activities, heart rate and GPS routes, '
                     'so the map no longer needs Health Connect consent.',
              style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
          if (_connected) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: AnimatedContainer(
              duration: const Duration(milliseconds: 250), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _checkErr != null ? s.errorContainer : (_checking ? s.surfaceContainerHigh : s.primaryContainer), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Icon(_checkErr != null ? Icons.error_outline_rounded : (_checking ? Icons.sync_rounded : Icons.check_circle_rounded),
                    color: _checkErr != null ? s.onErrorContainer : s.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(child: Text(
                    _checking ? (isFr ? 'Vérification de la connexion…' : 'Checking the connection…')
                        : _checkErr ?? (isFr ? 'Connecté, ça fonctionne${_okName != null ? ' · $_okName' : ''}' : 'Connected and working${_okName != null ? ' · $_okName' : ''}'),
                    style: t.bodyLarge?.copyWith(color: _checkErr != null ? s.onErrorContainer : s.onPrimaryContainer))),
              ]))),
          SettingsSection(label: isFr ? 'Connexion' : 'Connection', children: [
            SettingTile(leading: const Icon(Icons.key_rounded), title: Text(isFr ? '1. Crée ta clé API' : '1. Create your API key'),
                subtitle: Text(isFr ? 'intervals.icu › Paramètres › tout en bas : « Paramètres pour les développeurs » › Créer une clé API.'
                                    : 'intervals.icu › Settings › bottom of the page: “Developer settings” › Create API key.'),
                trailing: const Icon(Icons.open_in_new_rounded), onTap: () => launchUrl(Uri.parse('https://intervals.icu/settings'), mode: LaunchMode.externalApplication)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TextField(controller: _key, obscureText: true, autocorrect: false, enableSuggestions: false,
              decoration: InputDecoration(labelText: isFr ? 'Clé API' : 'API key', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.vpn_key_rounded)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: TextField(controller: _id, autocorrect: false,
              decoration: InputDecoration(labelText: isFr ? 'ID athlète (laisse 0)' : 'Athlete ID (leave 0)', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person_rounded)))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: AnimatedSwitcher(duration: const Duration(milliseconds: 250),
              child: hs.intervalsBusy
                  ? Column(key: const ValueKey('busy'), children: [
                      const SizedBox(height: 56, child: Center(child: M3LoadingIndicator(size: 44))),
                      const SizedBox(height: 8),
                      Text(hs.intervalsStage, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: hs.intervalsProgress == 0 ? null : hs.intervalsProgress, borderRadius: BorderRadius.circular(8)),
                    ])
                  : FilledButton.icon(key: const ValueKey('go'), onPressed: _connect, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      icon: const Icon(Icons.sync_rounded), label: Text(_connected ? (isFr ? 'Synchroniser maintenant' : 'Sync now') : (isFr ? 'Connecter et synchroniser' : 'Connect and sync'))))),
          AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic, child: (hs.intervalsError == null && r == null)
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: hs.intervalsError != null ? s.errorContainer : s.primaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Text(hs.intervalsError ?? _summary(r!), style: t.bodyLarge?.copyWith(color: hs.intervalsError != null ? s.onErrorContainer : s.onPrimaryContainer)))),
          if (_last != null) Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text('${isFr ? 'Dernière synchro' : 'Last sync'} : ${fmtDate(_last!)}', style: t.labelMedium?.copyWith(color: s.onSurfaceVariant))),
          SettingsSection(label: isFr ? 'Quelle montre ?' : 'Which watch?', children: [
            SettingTile(leading: const Icon(Icons.watch_rounded), title: Text(isFr ? 'Samsung, Pixel Watch, Polar, Withings…' : 'Samsung, Pixel Watch, Polar, Withings…'),
                subtitle: Text(isFr ? 'Elles écrivent dans Health Connect : HealthStats les lit directement, sans Intervals.icu.' : 'They write to Health Connect: HealthStats reads them directly, no Intervals.icu needed.')),
            SettingTile(leading: const Icon(Icons.cloud_sync_rounded), title: Text(isFr ? 'Garmin, Suunto, COROS, Wahoo…' : 'Garmin, Suunto, COROS, Wahoo…'),
                subtitle: Text(isFr ? 'Connecte ta montre à Intervals.icu (Paramètres › Connexions), puis synchronise ici. Vérifie sur intervals.icu quelles marques sont prises en charge.' : 'Link your watch to Intervals.icu (Settings › Connections), then sync here. Check on intervals.icu which brands are supported.')),
            SettingTile(leading: const Icon(Icons.file_open_rounded), title: Text(isFr ? 'Huawei, Amazfit, Nothing, autres' : 'Huawei, Amazfit, Nothing, others'),
                subtitle: Text(isFr ? 'Exporte tes sorties en GPX/FIT depuis l’app de la montre, envoie-les sur Intervals.icu (ou utilise « Importer des activités »).' : 'Export your workouts as GPX/FIT from the watch app, upload them to Intervals.icu (or use “Import activities”).')),
            SettingTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('Strava'),
                subtitle: Text(isFr ? 'Les séances Strava ne passent pas par l’API d’Intervals.icu (interdit par Strava). Utilise l’archive .zip de Strava dans « Importer des activités ».' : 'Strava workouts are not available through Intervals.icu’s API (Strava forbids it). Use the Strava .zip archive in “Import activities”.')),
          ]),
          if (_connected) SettingsSection(label: isFr ? 'Compte' : 'Account', children: [
            SettingActionRow(icon: Icons.link_off_rounded, danger: true,
                title: _confirm ? (isFr ? 'Appuie encore pour confirmer' : 'Tap again to confirm') : (isFr ? 'Déconnecter Intervals.icu' : 'Disconnect Intervals.icu'),
                subtitle: _confirm ? (isFr ? 'La clé est effacée. Les activités déjà reçues restent.' : 'The key is erased. Activities already received stay.') : null,
                onTap: () async {
                  if (!_confirm) { setState(() => _confirm = true); return; }
                  await IntervalsService.forget();
                  if (mounted) setState(() { _confirm = false; _connected = false; _key.clear(); _id.text = '0'; _last = null; });
                }),
          ]),
        ]);
      })),
    );
  }

  String _summary(({int added, int matched, int strava, int known, int total}) r) {
    final n = r.added - r.matched;
    final p = <String>[];
    if (isFr) {
      if (n > 0) p.add('$n nouvelle${n > 1 ? 's' : ''} activité${n > 1 ? 's' : ''}');
      if (r.matched > 0) p.add('${r.matched} tracé${r.matched > 1 ? 's' : ''} ajouté${r.matched > 1 ? 's' : ''} à des séances existantes');
      if (r.known > 0) p.add('${r.known} déjà à jour');
      if (r.strava > 0) p.add('${r.strava} séance${r.strava > 1 ? 's' : ''} Strava ignorée${r.strava > 1 ? 's' : ''} (non disponibles)');
      return p.isEmpty ? 'Aucune activité trouvée (${r.total} reçues).' : p.join(' · ');
    }
    if (n > 0) p.add('$n new ${n > 1 ? 'activities' : 'activity'}');
    if (r.matched > 0) p.add('${r.matched} route${r.matched > 1 ? 's' : ''} added to existing sessions');
    if (r.known > 0) p.add('${r.known} already up to date');
    if (r.strava > 0) p.add('${r.strava} Strava session${r.strava > 1 ? 's' : ''} skipped (not available)');
    return p.isEmpty ? 'No activity found (${r.total} received).' : p.join(' · ');
  }
}
