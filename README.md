# HealthStats

App Android native (Kotlin, Jetpack Compose, Material 3) qui lit Health Connect : activités, cartes GPS, fréquence cardiaque, sommeil, graphiques.

- minSdk 26, targetSdk 35
- Build local : `gradle assembleDebug` (ou Android Studio)
- CI : GitHub Actions (`.github/workflows`)
- Signature : copier `debug.keystore` dans `app/` pour garder la même signature
