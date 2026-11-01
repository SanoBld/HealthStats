// L.xxx — UI labels (FR/EN). Add a key to _k for every new text.
import '../app_state.dart';

const Map<String, List<String>> _k = {
  // key: [fr, en]
  'colorPickerBrightness': ['Luminosité', 'Brightness'], 'colorPickerHue': ['Teinte', 'Hue'],
  'colorPickerInvalid': ['Hex invalide', 'Invalid hex'], 'colorPickerQuickColors': ['Couleurs rapides', 'Quick colors'],
  'colorPickerSaturation': ['Saturation', 'Saturation'], 'colorPickerTitle': ['Couleur', 'Color'],
  'commonApply': ['Appliquer', 'Apply'], 'commonCancel': ['Annuler', 'Cancel'], 'commonSave': ['Enregistrer', 'Save'],
  'exportCopied': ['Copié', 'Copied'], 'exportCopy': ['Copier', 'Copy'], 'exportFilename': ['healthstats_export', 'healthstats_export'],
  'exportInfo': ['Exporter vos données', 'Export your data'], 'exportJsonContent': ['Contenu JSON', 'JSON content'],
  'exportTitle': ['Export', 'Export'], 'restartHintFeatures': ['Redémarrez pour appliquer', 'Restart to apply'],
  'reorderCardsTitle': ['Ordre des cartes', 'Card order'],
  'navDashboard': ['Accueil', 'Home'], 'navActivities': ['Activités', 'Activities'], 'navMap': ['Carte', 'Map'],
  'navCharts': ['Graphiques', 'Charts'], 'navSettings': ['Réglages', 'Settings'],
  'settingsFavoritesSection': ['Favoris', 'Favorites'],
  'dashSortButton': ['Trier', 'Sort'], 'dashSortDone': ['Terminé', 'Done'], 'dashSortHint': ['Glissez pour réordonner', 'Drag to reorder'],
  'dashSeparateRow': ['Ligne séparée', 'Separate row'],
};

class _Strings {
  const _Strings();
  String _g(String k) {
    final v = _k[k];
    if (v == null) return k;
    return localeNotifier.value == 'fr' ? v[0] : v[1];
  }
  @override
  dynamic noSuchMethod(Invocation i) {
    final name = i.memberName.toString().replaceAll(RegExp(r'Symbol\("|"\)'), '');
    if (i.isGetter) return name == 'weekdaysShort' ? weekdaysShort : _g(name);
    return super.noSuchMethod(i);
  }
  List<String> get weekdaysShort => localeNotifier.value == 'fr'
      ? const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}

// ignore: non_constant_identifier_names
const dynamic L = _Strings();
