# HealthStats

Native Android app (Kotlin, Jetpack Compose, Material 3) that reads Health Connect:
all workouts, GPS maps, heart rate, steps, sleep and body metrics.

- minSdk 26, targetSdk 35, compileSdk 36
- Build: push to GitHub, the **Build APK** workflow gives you the APK in "Artifacts"
- Local build: `gradle assembleDebug` (Gradle 8.11.1, JDK 17) or open in Android Studio
- Release: push a tag `v1.0.0` -> **Release** workflow publishes the APK
- Signature: `app/debug.keystore` is committed on purpose, so each build installs over the last one

## Structure
- `data/health` : Health Connect (manager, repository, duplicate merger)
- `data/local` : settings (DataStore) and cache (JSON file)
- `data/remote` : Intervals.icu client
- `ui` : theme, components, screens, navigation
