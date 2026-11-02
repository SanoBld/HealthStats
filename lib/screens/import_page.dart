// Import of GPX / FIT files (Strava export, Garmin, Nothing, any app).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3LoadingIndicator;
import 'settings/settings_helpers.dart';
import 'settings/settings_rows.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  ({int added, int matched, int already, int failed})? _res;
  String? _err;
  bool _confirm = false;

  Future<void> _pick() async {
    final hs = HealthService.instance;
    setState(() { _res = null; _err = null; });
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any);
      final paths = r?.paths.whereType<String>().toList() ?? [];
      if (paths.isEmpty) return;
      final res = await hs.importFiles(paths);
      if (mounted) setState(() => _res = res);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance, s = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(child: ListenableBuilder(listenable: hs, builder: (ctx, _) => ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        M3PageHeader(title: isFr ? 'Importer des activités' : 'Import activities',
            subtitle: hs.importCount == 0 ? null : (isFr ? '${hs.importCount} importées' : '${hs.importCount} imported')),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: Text(
            isFr ? 'Choisis des fichiers GPX ou FIT (ou l’archive .zip de Strava). Le sport, la distance, le cœur et le tracé sont lus dans le fichier. '
                   'Si une séance existe déjà à la même heure, le tracé y est ajouté. Sinon, une nouvelle activité est créée.'
                 : 'Pick GPX or FIT files (or the Strava .zip archive). Sport, distance, heart rate and route are read from the file. '
                   'If a session already exists at the same time, the route is added to it. Otherwise a new activity is created.',
            style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: hs.importing
              ? const SizedBox(key: ValueKey('busy'), height: 72, child: Center(child: M3LoadingIndicator(size: 48)))
              : FilledButton.icon(key: const ValueKey('btn'), onPressed: _pick,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.file_open_rounded), label: Text(isFr ? 'Choisir des fichiers' : 'Choose files')),
        )),
        AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic, child: _res == null && _err == null
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _err != null ? s.errorContainer : s.primaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text(_err ?? _summary(_res!), style: t.bodyLarge?.copyWith(color: _err != null ? s.onErrorContainer : s.onPrimaryContainer)))),
        SettingsSection(label: isFr ? 'Où trouver les fichiers' : 'Where to find the files', children: [
          SettingTile(leading: const Icon(Icons.directions_run_rounded), title: const Text('Strava'),
              subtitle: Text(isFr ? 'Paramètres › Mon compte › Télécharger ou supprimer votre compte › Demander votre archive. Importe ensuite le .zip reçu par e-mail, tel quel.'
                                  : 'Settings › My Account › Download or delete your account › Request your archive. Then import the .zip you receive by e-mail, as is.')),
          SettingTile(leading: const Icon(Icons.watch_rounded), title: Text(isFr ? 'Garmin, Nothing, autres' : 'Garmin, Nothing, others'),
              subtitle: Text(isFr ? 'Exporte une activité en GPX ou FIT depuis l’app, puis choisis le fichier.' : 'Export an activity as GPX or FIT from the app, then pick the file.')),
        ]),
        if (hs.importCount > 0) SettingsSection(label: isFr ? 'Imports' : 'Imports', children: [
          SettingActionRow(icon: Icons.delete_outline_rounded, danger: true,
              title: _confirm ? (isFr ? 'Appuie encore pour confirmer' : 'Tap again to confirm') : (isFr ? 'Supprimer les activités importées' : 'Delete imported activities'),
              subtitle: _confirm ? (isFr ? 'Les séances Health Connect ne sont pas touchées.' : 'Health Connect sessions are not touched.') : null,
              onTap: () async {
                if (!_confirm) { setState(() => _confirm = true); return; }
                setState(() => _confirm = false);
                await hs.clearImports();
              }),
        ]),
      ]))),
    );
  }

  String _summary(({int added, int matched, int already, int failed}) r) {
    final n = r.added - r.matched;
    final parts = <String>[];
    if (isFr) {
      if (n > 0) parts.add('$n nouvelle${n > 1 ? 's' : ''} activité${n > 1 ? 's' : ''}');
      if (r.matched > 0) parts.add('${r.matched} tracé${r.matched > 1 ? 's' : ''} ajouté${r.matched > 1 ? 's' : ''} à des séances existantes');
      if (r.already > 0) parts.add('${r.already} déjà importée${r.already > 1 ? 's' : ''}');
      if (r.failed > 0) parts.add('${r.failed} fichier${r.failed > 1 ? 's' : ''} illisible${r.failed > 1 ? 's' : ''}');
      return parts.isEmpty ? 'Aucune activité trouvée dans ces fichiers.' : parts.join(' · ');
    }
    if (n > 0) parts.add('$n new ${n > 1 ? 'activities' : 'activity'}');
    if (r.matched > 0) parts.add('${r.matched} route${r.matched > 1 ? 's' : ''} added to existing sessions');
    if (r.already > 0) parts.add('${r.already} already imported');
    if (r.failed > 0) parts.add('${r.failed} unreadable file${r.failed > 1 ? 's' : ''}');
    return parts.isEmpty ? 'No activity found in these files.' : parts.join(' · ');
  }
}
