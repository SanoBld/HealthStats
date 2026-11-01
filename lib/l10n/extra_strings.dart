// tx('key', {'n': '3'}) — textes UI par clé (FR/EN), repli sur EN puis la clé.
import '../app_state.dart';

const Map<String, Map<String, String>> _kTx = {
  'fr': {
    'ui_total': 'Total', 'ui_avg_mo': 'Moy./période', 'cx_best_month': 'Meilleur', 'cx_by_month': 'Par période',
    'cx_cumulative': 'Cumulé', 'ui_activity_by_day_of_wee': 'Activité par jour de la semaine', 'cx_others': 'Autres',
    'ntf_dl_failed': 'Échec du téléchargement', 'ntf_dl_install_hint': 'Touchez pour installer',
    'ntf_dl_ready': 'Mise à jour prête', 'reorder': 'Réorganiser', 'sec_chart': 'Graphique',
    'stat_avg_day': 'Moy./jour', 'stat_avg_week': 'Moy./semaine', 'stat_days_active': 'Jours actifs',
    'stat_scrobbles_week': 'Activités cette semaine',
    'up_background': 'En arrière-plan', 'up_browser': 'Ouvrir dans le navigateur', 'up_close': 'Fermer',
    'up_downloading': 'Téléchargement…', 'up_failed': 'Échec', 'up_failed_body': 'La mise à jour a échoué.',
    'up_installing': 'Installation…', 'up_open_downloads': 'Ouvrir les téléchargements',
    'up_perm_body': "Autorisez l'installation d'applications inconnues pour HealthStats.",
    'up_perm_title': 'Autorisation requise', 'up_restart': 'Redémarrer', 'up_retry': 'Réessayer',
    'up_saved': 'Enregistré', 'up_title': 'Mise à jour', 'yr_months_full':
        'janvier,février,mars,avril,mai,juin,juillet,août,septembre,octobre,novembre,décembre',
  },
  'en': {
    'ui_total': 'Total', 'ui_avg_mo': 'Avg/period', 'cx_best_month': 'Best', 'cx_by_month': 'By period',
    'cx_cumulative': 'Cumulative', 'ui_activity_by_day_of_wee': 'Activity by day of week', 'cx_others': 'Others',
    'ntf_dl_failed': 'Download failed', 'ntf_dl_install_hint': 'Tap to install',
    'ntf_dl_ready': 'Update ready', 'reorder': 'Reorder', 'sec_chart': 'Chart',
    'stat_avg_day': 'Avg/day', 'stat_avg_week': 'Avg/week', 'stat_days_active': 'Active days',
    'stat_scrobbles_week': 'Activities this week',
    'up_background': 'In background', 'up_browser': 'Open in browser', 'up_close': 'Close',
    'up_downloading': 'Downloading…', 'up_failed': 'Failed', 'up_failed_body': 'The update failed.',
    'up_installing': 'Installing…', 'up_open_downloads': 'Open downloads',
    'up_perm_body': 'Allow installing unknown apps for HealthStats.',
    'up_perm_title': 'Permission required', 'up_restart': 'Restart', 'up_retry': 'Retry',
    'up_saved': 'Saved', 'up_title': 'Update', 'yr_months_full':
        'January,February,March,April,May,June,July,August,September,October,November,December',
  },
};

String tx(String key, [Map<String, String>? args]) {
  var s = _kTx[localeNotifier.value]?[key] ?? _kTx['en']![key] ?? key;
  args?.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}
