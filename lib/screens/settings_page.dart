// Settings hub: one card per category, each opens its own page (like LastStats).
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/health_service.dart';
import '../services/update_service.dart';
import '../widgets/hs_widgets.dart';
import '../widgets/m3_components.dart';
import '../widgets/skeleton.dart' show M3Spinner;
import '../widgets/update_install_sheet.dart';
import 'health_cache_page.dart';
import 'import_page.dart';
import 'intervals_page.dart';
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
  late DateTime? _birth = parseBirth(profileBirthNotifier.value);

  double _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() { _n.dispose(); _h.dispose(); _w.dispose(); super.dispose(); }

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
        f(_w, isFr ? 'Poids (kg)' : 'Weight (kg)', num: true),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
          readOnly: true,
          controller: TextEditingController(text: _birth == null ? '' : fmtDay(_birth!)),
          decoration: InputDecoration(
              labelText: isFr ? 'Date de naissance' : 'Birth date',
              suffixIcon: const Icon(Icons.cake_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
          onTap: () async {
            final d = await pickBirthDate(context, _birth);
            if (d != null) setState(() => _birth = d);
          },
        )),
        FilledButton(onPressed: () {
          profileNameNotifier.value = _n.text.trim();
          profileHeightNotifier.value = _d(_h); profileWeightNotifier.value = _d(_w);
          profileBirthNotifier.value = _birth == null ? '' : birthToStr(_birth!);
          Navigator.pop(context);
        }, child: Text(L.commonSave)),
      ]),
    );
  }
}

final Listenable _watch = Listenable.merge([
  HealthService.instance, themeModeNotifier, oledModeNotifier, hapticFeedbackNotifier, navLabelNotifier,
  textScaleNotifier, localeNotifier, unitsMetricNotifier, stepGoalNotifier, weeklyGoalNotifier,
  profileNameNotifier, profileBirthNotifier, accentNotifier, useDynamicColorNotifier, colorHarmonyNotifier, appFontNotifier,
  profileHeightNotifier, profileWeightNotifier, profileSexNotifier, sportColorsNotifier,
  showAdviceNotifier, hiddenTabsNotifier, hiddenCardsNotifier,
]);

class _SubPage extends StatelessWidget {
  final String title;
  final List<Widget> Function(BuildContext) rows;
  const _SubPage({required this.title, required this.rows});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: ListenableBuilder(
          listenable: _watch,
          builder: (ctx, _) => ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            M3PageHeader(title: title),
            ...rows(ctx),
          ]),
        )),
      );
}

void _open(BuildContext c, Widget page) => Navigator.push(c, MaterialPageRoute(builder: (_) => page));

class SettingsPage extends StatelessWidget {
  final bool pushed; // opened from the profile: show a back button
  const SettingsPage({super.key, this.pushed = false});

  Widget _card(BuildContext c, IconData i, String title, String sub, Widget page) => SettingTile(
        leading: Icon(i), title: Text(title), subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _open(c, page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _watch,
        builder: (ctx, _) => SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          M3PageHeader(showBack: pushed, title: L.navSettings),
          SettingsSection(label: isFr ? 'Compte' : 'Account', children: [
            _card(ctx, Icons.person_rounded, profileNameNotifier.value.isEmpty ? (isFr ? 'Profil' : 'Profile') : profileNameNotifier.value,
                isFr ? 'Nom, taille, poids, naissance, objectifs' : 'Name, height, weight, birth, goals',
                _SubPage(title: isFr ? 'Profil' : 'Profile', rows: _profileRows)),
            _card(ctx, Icons.favorite_rounded, 'Google Health', isFr ? 'Connexion, synchro, autorisations' : 'Connection, sync, permissions',
                _SubPage(title: 'Google Health', rows: _healthRows)),
          ]),
          SettingsSection(label: isFr ? 'Application' : 'App', children: [
            _card(ctx, Icons.palette_rounded, isFr ? 'Apparence' : 'Appearance', isFr ? 'Thème, couleurs, police, texte' : 'Theme, colors, font, text',
                _SubPage(title: isFr ? 'Apparence' : 'Appearance', rows: _appearanceRows)),
            _card(ctx, Icons.tune_rounded, isFr ? 'Préférences' : 'Preferences', isFr ? 'Langue, unités, haptique' : 'Language, units, haptics',
                _SubPage(title: isFr ? 'Préférences' : 'Preferences', rows: _prefRows)),
            _card(ctx, Icons.cloud_sync_rounded, 'Intervals.icu', isFr ? 'Activités, cœur et tracés GPS (gratuit)' : 'Activities, heart rate and GPS routes (free)', const IntervalsPage()),
            _card(ctx, Icons.file_open_rounded, isFr ? 'Importer des activités' : 'Import activities', isFr ? 'Fichiers GPX / FIT, archive Strava' : 'GPX / FIT files, Strava archive', const ImportPage()),
            _card(ctx, Icons.storage_rounded, 'Cache', isFr ? 'Taille, tracés, vidage' : 'Size, routes, clearing', const HealthCachePage()),
            _card(ctx, Icons.system_update_rounded, isFr ? 'Mises à jour' : 'Updates', 'v${UpdateService.currentVersion}',
                const _UpdatesPage()),
            _card(ctx, Icons.info_rounded, isFr ? 'À propos' : 'About', 'HealthStats ${UpdateService.displayVersion ?? 'dev'}',
                _SubPage(title: isFr ? 'À propos' : 'About', rows: (c) => [
                  SettingsSection(label: 'HealthStats', children: [
                    SettingTile(leading: const Icon(Icons.info_rounded), title: const Text('HealthStats'),
                        subtitle: Text(UpdateService.displayVersion ?? 'dev')),
                  ]),
                ])),
          ]),
        ])),
      );
}

List<Widget> _profileRows(BuildContext ctx) {
  final birth = parseBirth(profileBirthNotifier.value);
  return [
    SettingsSection(label: isFr ? 'Profil' : 'Profile', children: [
      SettingTile(leading: const Icon(Icons.person_rounded),
          title: Text(profileNameNotifier.value.isEmpty ? (isFr ? 'Configurer' : 'Set up') : profileNameNotifier.value),
          subtitle: Text(birth == null ? (isFr ? 'Nom, taille, poids, naissance' : 'Name, height, weight, birth') : fmtDay(birth)),
          trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showProfileSheet(ctx)),
      SettingTile(leading: const Icon(Icons.cake_rounded), title: Text(isFr ? 'Date de naissance' : 'Birth date'),
          subtitle: Text(birth == null ? (isFr ? 'Non renseignée (sert aux zones de FC)' : 'Not set (used for HR zones)') : fmtDay(birth)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final d = await pickBirthDate(ctx, birth);
            if (d != null) profileBirthNotifier.value = birthToStr(d);
          }),
      InlineNumberTile(icon: Icons.height_rounded, title: isFr ? 'Taille' : 'Height', unit: 'cm',
          value: profileHeightNotifier.value, onSave: (v) => profileHeightNotifier.value = v),
      InlineNumberTile(icon: Icons.monitor_weight_rounded, title: isFr ? 'Poids' : 'Weight', unit: 'kg',
          value: profileWeightNotifier.value, onSave: (v) => profileWeightNotifier.value = v),
      SettingChoiceRow(icon: Icons.wc_rounded, title: isFr ? 'Sexe' : 'Sex',
          options: [('m', isFr ? 'Homme' : 'Male', null), ('f', isFr ? 'Femme' : 'Female', null), ('x', isFr ? 'Autre' : 'Other', null)],
          value: profileSexNotifier.value.isEmpty ? 'x' : profileSexNotifier.value, onChanged: (v) => profileSexNotifier.value = v),
    ]),
    SettingsSection(label: isFr ? 'Objectifs' : 'Goals', children: [
      SettingSliderRow(icon: Icons.directions_walk_rounded, title: isFr ? 'Objectif de pas / jour' : 'Daily step goal',
          valueLabel: '${stepGoalNotifier.value}', value: stepGoalNotifier.value.toDouble(), min: 2000, max: 30000, divisions: 28,
          onChanged: (v) => stepGoalNotifier.value = v.round(), onChangeEnd: (_) {}),
      SettingSliderRow(icon: Icons.event_available_rounded, title: isFr ? 'Séances / semaine' : 'Workouts / week',
          valueLabel: '${weeklyGoalNotifier.value}', value: weeklyGoalNotifier.value.toDouble(), min: 1, max: 14, divisions: 13,
          onChanged: (v) => weeklyGoalNotifier.value = v.round(), onChangeEnd: (_) {}),
    ]),
  ];
}

List<Widget> _healthRows(BuildContext ctx) {
  final hs = HealthService.instance;
  return [
    SettingsSection(label: 'Health Connect', children: [
      SettingsStatusCard(on: hs.permitted, title: hs.permitted ? (isFr ? 'Health Connect connecté' : 'Health Connect connected') : (isFr ? 'Non connecté' : 'Not connected'),
          subtitle: hs.lastSync == null ? '—' : '${isFr ? 'Dernière synchro' : 'Last sync'} : ${fmtDate(hs.lastSync!)}',
          iconOn: Icons.favorite_rounded, iconOff: Icons.heart_broken_rounded),
      if (hs.permitted && !(hs.hasRoutePerm && hs.hasHistoryPerm))
        SettingActionRow(icon: Icons.warning_amber_rounded,
            title: isFr ? 'Autorisations manquantes (tracés GPS / historique)' : 'Missing permissions (GPS routes / history)',
            onTap: hs.requestPermissions),
      SettingActionRow(icon: Icons.sync_rounded, title: isFr ? 'Synchroniser maintenant' : 'Sync now', onTap: () => hs.permitted ? hs.sync() : hs.requestPermissions()),
      SettingActionRow(icon: Icons.verified_user_rounded, title: isFr ? 'Redemander les autorisations' : 'Request permissions again', onTap: hs.requestPermissions),
      SettingActionRow(icon: Icons.lock_open_rounded, title: isFr ? 'Gérer dans Health Connect' : 'Manage in Health Connect', onTap: hs.openHealthConnect),
    ]),
  ];
}

List<Widget> _appearanceRows(BuildContext ctx) => [
      SettingsSection(label: isFr ? 'Thème' : 'Theme', children: [
        SettingChoiceRow(icon: Icons.brightness_6_rounded, title: isFr ? 'Mode' : 'Mode',
            options: [('0', isFr ? 'Système' : 'System', null), ('1', isFr ? 'Clair' : 'Light', null), ('2', isFr ? 'Sombre' : 'Dark', null)],
            value: '${themeModeNotifier.value.index}', onChanged: (v) => themeModeNotifier.value = ThemeMode.values[int.parse(v)]),
        SettingSwitchRow(icon: Icons.auto_awesome_rounded, title: isFr ? 'Couleurs dynamiques' : 'Dynamic colors', value: useDynamicColorNotifier.value, onChanged: (v) => useDynamicColorNotifier.value = v),
        SettingChoiceRow(icon: Icons.tune_rounded, title: isFr ? 'Harmonie des couleurs' : 'Color harmony',
            options: [('mono', isFr ? 'Une teinte' : 'One hue', null), ('classic', isFr ? 'Classique' : 'Classic', null),
              ('tinted', isFr ? 'Teinté' : 'Tinted', null), ('vivid', isFr ? 'Vif' : 'Vivid', null), ('soft', isFr ? 'Doux' : 'Soft', null)],
            value: colorHarmonyNotifier.value, onChanged: (v) => colorHarmonyNotifier.value = v),
        SettingTile(
          leading: const Icon(Icons.color_lens_rounded), title: Text(isFr ? 'Couleur d\'accent' : 'Accent color'),
          trailing: Container(width: 28, height: 28, decoration: BoxDecoration(color: accentNotifier.value, shape: BoxShape.circle)),
          onTap: () async {
            final c = await showDialog<Color>(context: ctx, builder: (_) => ColorPickerDialog(initialColor: accentNotifier.value));
            if (c != null) accentNotifier.value = c;
          },
        ),
        SettingSwitchRow(icon: Icons.brightness_2_rounded, title: 'OLED', value: oledModeNotifier.value, onChanged: (v) => oledModeNotifier.value = v),
        SettingSwitchRow(icon: Icons.palette_outlined, title: isFr ? 'Couleurs par sport' : 'Sport colors', value: sportColorsNotifier.value, onChanged: (v) => sportColorsNotifier.value = v),
      ]),
      SettingsSection(label: isFr ? 'Affichage' : 'Display', children: [
        SettingSwitchRow(icon: Icons.lightbulb_outline_rounded, title: isFr ? 'Afficher les conseils' : 'Show advice',
            value: showAdviceNotifier.value, onChanged: (v) => showAdviceNotifier.value = v),
        for (final e in [
          ('activities', Icons.fitness_center_rounded, isFr ? 'Onglet Activités' : 'Activities tab'),
          ('map', Icons.map_rounded, isFr ? 'Onglet Carte' : 'Map tab'),
          ('search', Icons.search_rounded, isFr ? 'Onglet Recherche' : 'Search tab'),
          ('charts', Icons.auto_graph_rounded, isFr ? 'Onglet Graphiques' : 'Charts tab'),
        ]) SettingSwitchRow(icon: e.$2, title: e.$3, value: !isHidden(hiddenTabsNotifier, e.$1),
            onChanged: (v) => setHidden(hiddenTabsNotifier, e.$1, !v)),
        for (final e in [
          ('greeting', Icons.waving_hand_rounded, isFr ? 'Message d\'accueil' : 'Greeting'),
          ('readiness', Icons.bolt_rounded, isFr ? 'Forme du jour' : 'Readiness'),
          ('goals', Icons.flag_rounded, isFr ? 'Objectif de la semaine' : 'Weekly goal'),
          ('steps7', Icons.directions_walk_rounded, isFr ? 'Pas, 7 derniers jours' : 'Steps, last 7 days'),
          ('kcal', Icons.local_fire_department_rounded, isFr ? 'Calories actives' : 'Active calories'),
          ('onthisday', Icons.history_toggle_off_rounded, isFr ? 'Jour pour jour' : 'On this day'),
          ('records', Icons.emoji_events_rounded, isFr ? 'Records personnels' : 'Personal records'),
          ('sleep', Icons.bedtime_rounded, isFr ? 'Carte Sommeil' : 'Sleep card'),
          ('heart', Icons.favorite_rounded, isFr ? 'Carte Fréquence cardiaque' : 'Heart rate card'),
          ('vitals', Icons.monitor_heart_rounded, isFr ? 'HRV, SpO₂ et poids' : 'HRV, SpO₂ and weight'),
          ('week', Icons.date_range_rounded, isFr ? 'Section Cette semaine' : 'This week section'),
        ]) SettingSwitchRow(icon: e.$2, title: e.$3, value: !isHidden(hiddenCardsNotifier, e.$1),
            onChanged: (v) => setHidden(hiddenCardsNotifier, e.$1, !v)),
      ]),
      SettingsSection(label: isFr ? 'Texte' : 'Text', children: [
        SettingChoiceRow(icon: Icons.font_download_rounded, title: isFr ? 'Police' : 'Font', previewFonts: true,
            options: const [
              ('GoogleSansFlex', 'Google Sans Flex', null), ('Roboto', 'Roboto', null), ('Inter', 'Inter', null),
              ('OpenSans', 'Open Sans', null), ('RobotoSlab', 'Roboto Slab', null), ('SpaceGrotesk', 'Space Grotesk', null),
              ('SpaceMono', 'Space Mono', null), ('DancingScript', 'Dancing Script', null), ('Mynerve', 'Mynerve', null),
              ('SingleDay', 'Single Day', null),
            ],
            value: appFontNotifier.value, onChanged: (v) => appFontNotifier.value = v),
        SettingSliderRow(icon: Icons.format_size_rounded, title: isFr ? 'Taille du texte' : 'Text size', valueLabel: '${(textScaleNotifier.value * 100).round()}%',
            value: textScaleNotifier.value, min: 0.8, max: 1.5, divisions: 14, onChanged: (v) => textScaleNotifier.value = v, onChangeEnd: (_) {}),
      ]),
      SettingsSection(label: isFr ? 'Navigation' : 'Navigation', children: [
        SettingSwitchRow(icon: Icons.label_rounded, title: isFr ? 'Libellés de navigation' : 'Navigation labels', value: navLabelNotifier.value, onChanged: (v) => navLabelNotifier.value = v),
      ]),
    ];

List<Widget> _prefRows(BuildContext ctx) => [
      SettingsSection(label: isFr ? 'Général' : 'General', children: [
        SettingChoiceRow(icon: Icons.language_rounded, title: isFr ? 'Langue' : 'Language',
            options: const [('fr', 'Français', null), ('en', 'English', null)], value: localeNotifier.value, onChanged: (v) => localeNotifier.value = v),
        SettingChoiceRow(icon: Icons.straighten_rounded, title: isFr ? 'Unités' : 'Units',
            options: const [('m', 'km / kg', null), ('i', 'mi / lb', null)],
            value: unitsMetricNotifier.value ? 'm' : 'i', onChanged: (v) => unitsMetricNotifier.value = v == 'm'),
        SettingSwitchRow(icon: Icons.vibration_rounded, title: isFr ? 'Retour haptique' : 'Haptics', value: hapticFeedbackNotifier.value, onChanged: (v) => hapticFeedbackNotifier.value = v),
      ]),
    ];

class _UpdatesPage extends StatefulWidget {
  const _UpdatesPage();
  @override
  State<_UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<_UpdatesPage> {
  bool _checking = false;
  bool _beta = false;
  String? _upMsg;

  Future<void> _checkUpdate() async {
    setState(() { _checking = true; _upMsg = null; });
    final info = await UpdateService.checkForUpdate(channel: _beta ? UpdateChannel.beta : UpdateChannel.stable);
    if (!mounted) return;
    setState(() { _checking = false; _upMsg = info == null ? (isFr ? 'À jour' : 'Up to date ✔') : 'v${info.version}'; });
    if (info != null && info.downloadUrl != null) {
      await showUpdateInstall(context, url: info.downloadUrl!, kind: info.downloadKind, version: info.version);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          M3PageHeader(title: isFr ? 'Mises à jour' : 'Updates'),
          SettingsSection(label: isFr ? 'Mises à jour' : 'Updates', children: [
            SettingTile(leading: const Icon(Icons.system_update_rounded), title: Text(isFr ? 'Rechercher une mise à jour' : 'Check for updates'),
                subtitle: Text(_upMsg ?? 'v${UpdateService.currentVersion}'),
                trailing: _checking ? const SizedBox(width: 24, height: 24, child: M3Spinner()) : null,
                onTap: _checking ? null : _checkUpdate),
            SettingSwitchRow(icon: Icons.science_rounded, title: isFr ? 'Versions bêta' : 'Beta versions', value: _beta, onChanged: (v) => setState(() => _beta = v)),
          ]),
        ])),
      );
}
