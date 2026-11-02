// Advanced cache page: sizes, counts, and separate clear buttons (always with a confirmation).
import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import 'settings/settings_helpers.dart';
import 'settings/settings_rows.dart';

class HealthCachePage extends StatefulWidget {
  const HealthCachePage({super.key});
  @override
  State<HealthCachePage> createState() => _HealthCachePageState();
}

class _HealthCachePageState extends State<HealthCachePage> {
  (int, int) _sizes = (0, 0);

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    final s = await HealthService.instance.cacheSizes();
    if (mounted) setState(() => _sizes = s);
  }

  String _fmt(int b) => b < 1024 ? '$b B' : b < 1048576 ? '${(b / 1024).toStringAsFixed(0)} KB' : '${(b / 1048576).toStringAsFixed(1)} MB';

  Future<void> _ask(String title, String msg, Future<void> Function() run) async {
    final ok = await confirmDialog(context, title: title, message: msg, ok: isFr ? 'Vider' : 'Clear', icon: Icons.delete_outline_rounded);
    if (!ok) return;
    await run();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return Scaffold(
      body: SafeArea(child: ListenableBuilder(listenable: hs, builder: (ctx, _) => ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        M3PageHeader(title: 'Cache', subtitle: _fmt(_sizes.$1 + _sizes.$2)),
        const SizedBox(height: 8),
        StatGrid([
          StatTile(icon: Icons.fitness_center_rounded, value: '${hs.workouts.length}', label: isFr ? 'Activités' : 'Activities'),
          StatTile(icon: Icons.calendar_month_rounded, value: '${hs.days.length}', label: isFr ? 'Jours' : 'Days'),
          StatTile(icon: Icons.route_rounded, value: '${hs.tracks.length}', label: isFr ? 'Tracés' : 'Routes'),
          StatTile(icon: Icons.apps_rounded, value: '${hs.appIcons.length}', label: isFr ? 'Logos d\'applis' : 'App icons'),
        ]),
        SettingsSection(label: isFr ? 'Détail' : 'Details', children: [
          SettingTile(leading: const Icon(Icons.storage_rounded), title: Text(isFr ? 'Activités et jours' : 'Activities and days'), subtitle: Text(_fmt(_sizes.$1))),
          SettingTile(leading: const Icon(Icons.map_rounded), title: Text(isFr ? 'Tracés de la carte' : 'Map routes'), subtitle: Text(_fmt(_sizes.$2))),
          SettingTile(leading: const Icon(Icons.history_rounded), title: Text(isFr ? 'Dernière synchro' : 'Last sync'),
              subtitle: Text(hs.lastSync == null ? '—' : fmtDate(hs.lastSync!))),
        ]),
        SettingsSection(label: isFr ? 'Actions' : 'Actions', children: [
          SettingActionRow(icon: Icons.sync_rounded, title: isFr ? 'Resynchroniser maintenant' : 'Sync now',
              onTap: () => hs.permitted ? hs.sync() : hs.requestPermissions()),
          SettingActionRow(icon: Icons.map_outlined, title: isFr ? 'Vider les tracés' : 'Clear routes',
              subtitle: isFr ? 'Relus depuis Health Connect' : 'Read again from Health Connect',
              onTap: () => _ask(isFr ? 'Vider les tracés ?' : 'Clear routes?',
                  isFr ? 'Les tracés de la carte (${_fmt(_sizes.$2)}) seront supprimés.' : 'Map routes (${_fmt(_sizes.$2)}) will be deleted.', hs.clearTracks)),
          SettingActionRow(icon: Icons.fitness_center_rounded, title: isFr ? 'Vider les activités' : 'Clear activities',
              onTap: () => _ask(isFr ? 'Vider les activités ?' : 'Clear activities?',
                  isFr ? 'Les activités enregistrées (${_fmt(_sizes.$1)}) seront supprimées jusqu\'à la prochaine synchro.' : 'Saved activities (${_fmt(_sizes.$1)}) will be deleted until the next sync.', hs.clearActivities)),
          SettingActionRow(icon: Icons.delete_forever_rounded, danger: true, title: isFr ? 'Tout vider' : 'Clear everything',
              onTap: () => _ask(isFr ? 'Tout vider ?' : 'Clear everything?',
                  isFr ? 'Activités, jours et tracés seront supprimés, puis relus depuis Health Connect.' : 'Activities, days and routes will be deleted, then read again from Health Connect.',
                  () async { await hs.clearCache(); hs.sync(); })),
        ]),
      ]))),
    );
  }
}
