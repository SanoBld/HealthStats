# HealthStats

Vos stats de santé **Google Health (Health Connect)** : dernières activités, tracés GPS sur carte,
détail des séances (muscu, course, vélo…), graphiques par jour / semaine / mois.
Design repris de **LastStats** (thème Nothing OS, Material 3). **Android uniquement.**

## Fonctionnalités
- Profil configuré au 1er lancement (modifiable en haut du dashboard).
- Dashboard : pas du jour, dernière séance, dernière séance de muscu, résumé de la semaine, récents.
- Activités : liste filtrable par sport → détail (carte GPS, allure, FC, dénivelé, séries).
- Carte : tous les tracés GPS sur 7 j / 30 j / 90 j / tout.
- Graphiques (repris de LastStats) : tendance zoomable, jours de la semaine, répartition par sport.
- Réglages : thème, accent, unités, objectifs, Health Connect, mises à jour.

## Mettre à jour sans désinstaller
L'APK est signé avec `android/debug.keystore` (committé) → même signature à chaque build.
1. Remplacez `YOUR_GITHUB_USER` dans `lib/services/update_service.dart` par votre pseudo GitHub.
2. Poussez un tag `v0.1.1` (ou lancez *Release HealthStats* dans l'onglet Actions).
3. Le workflow construit les APK **arm64-v8a, armeabi-v7a, x86_64 et universal** et les publie.
4. Dans l'app : Réglages → Mises à jour (installe par-dessus).

## Développement
```
flutter pub get
dart run flutter_launcher_icons
flutter run
```
Prérequis : Health Connect installé (intégré à Android 14+), minSdk 26.
