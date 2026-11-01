// Réglages (même structure que LastStats : sections, lignes, feuilles).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/health_service.dart';
import '../services/update_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/update_install_sheet.dart';
import 'settings/settings_helpers.dart';
import 'settings/settings_rows.dart';

Future<void> showProfileSheet(BuildContext context) => showModalBottomSheet(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => const _ProfileSheet());

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final _n = TextEditingController(text: profileNameNotifier.value);
  late final _h = TextEditingController(text: profileHeightNotifier.value > 0 ? '${profileHeightNotifier.value}' : '');
  late final _w = TextEditingController(text: profileWeightNotifier.value > 0 ? '${profileWeightNotifier.value}' : '');
  late final _y = TextEditingController(text: profileBirthYearNotifier.value > 0 ? '${profileBirthYearNotifier.value}' : '');

  double _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    Widget f(TextEditingController c, String l, {bool num = false}) => Padding(padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : TextInputType.name,
            decoration: InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)))));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isFr ? 'Mon profil' : 'My profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        f(_n, isFr ? 'Prénom' : 'Name'), f(_h, isFr ? 'Taille (cm)' : 'Height (cm)', num: true),
        f(_w, isFr ? 'Poids (kg)' : 'Weight (kg)', num: true), f(_y, isFr ? 'Année de naissance' : 'Birth year', num: true),
        FilledButton(onPressed: () {
          profileNameNotifier.value = _n.text.trim();
          profileHeightNotifier.value = _d(_h); profileWeightNotifier.value = _d(_w);
          profileBirthYearNotifier.value = int.tryParse(_y.text) ?? 0;
          Navigator.pop(context);
        }, child: Text(L.commonSave)),
      ]),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checking = false;
  bool _beta = false;
  String? _upMsg;

  Future<void> _checkUpdate() async {
    setState(() { _checking = true; _upMsg = null; });
    final info = await UpdateService.checkForUpdate(channel: _beta ? UpdateChannel.beta : UpdateChannel.stable);
    if (!mounted) return;
    setState(() { _checking = false; _upMsg = info == null ? (isFr ? 'À jour ✔' : 'Up to date ✔') : 'v${info.version}'; });
    if (info != null && info.downloadUrl != null) {
      await showUpdateInstall(context, url: info.downloadUrl!, kind: info.downloadKind, version: info.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hs = HealthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([hs, themeModeNotifier, themeStyleNotifier, nothingAccentNotifier, oledModeNotifier,
        hapticFeedbackNotifier, navLabelNotifier, textScaleNotifier, localeNotifier, unitsMetricNotifier, stepGoalNotifier,
        weeklyGoalNotifier, profileNameNotifier, accentNotifier, useDynamicColorNotifier]),
      builder: (ctx, _) => SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        M3PageHeader(title: L.navSettings),

        SettingsSection(label: isFr ? 'Profil' : 'Profile', children: [
          SettingTile(leading: const Icon(Icons.person_rounded), title: Text(profileNameNotifier.value.isEmpty ? (isFr ? 'Configurer' : 'Set up') : profileNameNotifier.value),
              subtitle: Text(isFr ? 'Nom, taille, poids, naissance' : 'Name, height, weight, birth'),
              trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showProfileSheet(ctx)),
          SettingChoiceRow(icon: Icons.straighten_rounded, title: isFr ? 'Unités' : 'Units',
              options: const [('m', 'km / kg', null), ('i', 'mi / lb', null)],
              value: unitsMetricNotifier.value ? 'm' : 'i', onChanged: (v) => unitsMetricNotifier.value = v == 'm'),
          SettingSliderRow(icon: Icons.directions_walk_rounded, title: isFr ? 'Objectif de pas / jour' : 'Daily step goal',
              valueLabel: '${stepGoalNotifier.value}', value: stepGoalNotifier.value.toDouble(), min: 2000, max: 30000, divisions: 28,
              onChanged: (v) => stepGoalNotifier.value = v.round(), onChangeEnd: (_) {}),
          SettingSliderRow(icon: Icons.event_available_rounded, title: isFr ? 'Séances / semaine' : 'Workouts / week',
              valueLabel: '${weeklyGoalNotifier.value}', value: weeklyGoalNotifier.value.toDouble(), min: 1, max: 14, divisions: 13,
              onChanged: (v) => weeklyGoalNotifier.value = v.round(), onChangeEnd: (_) {}),
        ]),

        SettingsSection(label: 'Google Health', children: [
          SettingsStatusCard(on: hs.permitted, title: hs.permitted ? (isFr ? 'Health Connect connecté' : 'Health Connect connected') : (isFr ? 'Non connecté' : 'Not connected'),
              subtitle: hs.lastSync == null ? '—' : '${isFr ? 'Dernière synchro' : 'Last sync'} : ${fmtDate(hs.lastSync!)}',
              iconOn: Icons.favorite_rounded, iconOff: Icons.heart_broken_rounded),
          SettingActionRow(icon: Icons.sync_rounded, title: isFr ? 'Synchroniser maintenant' : 'Sync now', onTap: () => hs.permitted ? hs.sync() : hs.requestPermissions()),
          SettingActionRow(icon: Icons.lock_open_rounded, title: isFr ? 'Gérer les autorisations' : 'Manage permissions', onTap: hs.openHealthConnect),
          SettingActionRow(icon: Icons.delete_outline_rounded, title: isFr ? 'Vider le cache local' : 'Clear local cache', onTap: hs.clearCache),
        ]),

        SettingsSection(label: isFr ? 'Apparence' : 'Appearance', children: [
          SettingChoiceRow(icon: Icons.brightness_6_rounded, title: isFr ? 'Thème' : 'Theme',
              options: [('0', isFr ? 'Système' : 'System', null), ('1', isFr ? 'Clair' : 'Light', null), ('2', isFr ? 'Sombre' : 'Dark', null)],
              value: '${themeModeNotifier.value.index}', onChanged: (v) => themeModeNotifier.value = ThemeMode.values[int.parse(v)]),
          SettingChoiceRow(icon: Icons.palette_rounded, title: isFr ? 'Style' : 'Style',
              options: const [('nothing', 'Nothing', null), ('default', 'Material You', null)],
              value: themeStyleNotifier.value, onChanged: (v) => themeStyleNotifier.value = v),
          if (themeStyleNotifier.value == 'nothing')
            SettingChoiceRow(icon: Icons.color_lens_rounded, title: isFr ? 'Accent' : 'Accent',
                options: [('classic', isFr ? 'Rouge' : 'Red', null), ('mixed', isFr ? 'Rouge + jaune' : 'Red + yellow', null)],
                value: nothingAccentNotifier.value, onChanged: (v) => nothingAccentNotifier.value = v)
          else ...[
            SettingSwitchRow(icon: Icons.auto_awesome_rounded, title: isFr ? 'Couleurs dynamiques' : 'Dynamic colors', value: useDynamicColorNotifier.value, onChanged: (v) => useDynamicColorNotifier.value = v),
            SettingSwitchRow(icon: Icons.brightness_2_rounded, title: 'OLED', value: oledModeNotifier.value, onChanged: (v) => oledModeNotifier.value = v),
          ],
          SettingSwitchRow(icon: Icons.label_rounded, title: isFr ? 'Libellés de navigation' : 'Navigation labels', value: navLabelNotifier.value, onChanged: (v) => navLabelNotifier.value = v),
          SettingSwitchRow(icon: Icons.vibration_rounded, title: isFr ? 'Retour haptique' : 'Haptics', value: hapticFeedbackNotifier.value, onChanged: (v) => hapticFeedbackNotifier.value = v),
          SettingSliderRow(icon: Icons.format_size_rounded, title: isFr ? 'Taille du texte' : 'Text size', valueLabel: '${(textScaleNotifier.value * 100).round()}%',
              value: textScaleNotifier.value, min: 0.8, max: 1.5, divisions: 14, onChanged: (v) => textScaleNotifier.value = v, onChangeEnd: (_) {}),
          SettingChoiceRow(icon: Icons.language_rounded, title: isFr ? 'Langue' : 'Language',
              options: const [('fr', 'Français', null), ('en', 'English', null)], value: localeNotifier.value, onChanged: (v) => localeNotifier.value = v),
        ]),

        SettingsSection(label: isFr ? 'Mises à jour' : 'Updates', children: [
          SettingTile(leading: const Icon(Icons.system_update_rounded), title: Text(isFr ? 'Rechercher une mise à jour' : 'Check for updates'),
              subtitle: Text(_upMsg ?? 'v${UpdateService.currentVersion}'),
              trailing: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null, onTap: _checking ? null : _checkUpdate),
          SettingSwitchRow(icon: Icons.science_rounded, title: isFr ? 'Versions bêta' : 'Beta versions', value: _beta, onChanged: (v) => setState(() => _beta = v)),
        ]),

        SettingsSection(label: isFr ? 'À propos' : 'About', children: [
          SettingTile(leading: const Icon(Icons.info_rounded), title: const Text('HealthStats'), subtitle: Text(UpdateService.displayVersion ?? 'dev')),
        ]),
      ])),
    );
  }
}
