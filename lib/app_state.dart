// Global state (ValueNotifier) — same names as LastStats so theme & settings code can be reused.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeNotifier        = ValueNotifier<ThemeMode>(ThemeMode.system);
final accentNotifier           = ValueNotifier<Color>(const Color(0xFFFF2020));
final useDynamicColorNotifier  = ValueNotifier<bool>(false);
final localeNotifier           = ValueNotifier<String>('fr');
final displayNameNotifier      = ValueNotifier<String>('');
final oledModeNotifier         = ValueNotifier<bool>(false);
final hapticFeedbackNotifier   = ValueNotifier<bool>(true);
final navLabelNotifier         = ValueNotifier<bool>(true);
final textScaleNotifier        = ValueNotifier<double>(1.1);
final appFontNotifier          = ValueNotifier<String>('GoogleSansFlex');
final imageShapeNotifier       = ValueNotifier<String>('mix');
final minuteTickNotifier       = ValueNotifier<int>(0);
// Health profile (set up on first launch)
final profileNameNotifier      = ValueNotifier<String>('');
final profileHeightNotifier    = ValueNotifier<double>(0);   // cm
final profileWeightNotifier    = ValueNotifier<double>(0);   // kg
final profileBirthNotifier     = ValueNotifier<String>(''); // yyyy-MM-dd
final profileSexNotifier       = ValueNotifier<String>('');  // m | f | x
final stepGoalNotifier         = ValueNotifier<int>(10000);
final weeklyGoalNotifier       = ValueNotifier<int>(3);      // séances/semaine
final unitsMetricNotifier      = ValueNotifier<bool>(true);
final onboardedNotifier        = ValueNotifier<bool>(false);
final sportColorsNotifier      = ValueNotifier<bool>(true);  // one colour per sport (off = accent only)

Future<void> loadAppState() async {
  final p = await SharedPreferences.getInstance();
  themeModeNotifier.value = ThemeMode.values[(p.getInt('hs_theme') ?? 0).clamp(0, 2)];
  localeNotifier.value = p.getString('hs_locale') ?? 'fr';
  oledModeNotifier.value = p.getBool('hs_oled') ?? false;
  hapticFeedbackNotifier.value = p.getBool('hs_haptic') ?? true;
  navLabelNotifier.value = p.getBool('hs_navlabels') ?? true;
  textScaleNotifier.value = p.getDouble('hs_textscale') ?? 1.1;
  appFontNotifier.value = p.getString('hs_font') ?? 'GoogleSansFlex';
  accentNotifier.value = Color(p.getInt('hs_accent') ?? 0xFFFF2020);
  profileNameNotifier.value = p.getString('hs_name') ?? '';
  profileHeightNotifier.value = p.getDouble('hs_height') ?? 0;
  profileWeightNotifier.value = p.getDouble('hs_weight') ?? 0;
  profileBirthNotifier.value = p.getString('hs_birthdate') ?? '';
  profileSexNotifier.value = p.getString('hs_sex') ?? '';
  stepGoalNotifier.value = p.getInt('hs_stepgoal') ?? 10000;
  weeklyGoalNotifier.value = p.getInt('hs_weeklygoal') ?? 3;
  unitsMetricNotifier.value = p.getBool('hs_metric') ?? true;
  onboardedNotifier.value = p.getBool('hs_onboarded') ?? false;
  sportColorsNotifier.value = p.getBool('hs_sportcolors') ?? true;
}

/// Binds every notifier to SharedPreferences (automatic write).
void bindPersistence(SharedPreferences p) {
  void b<T>(ValueNotifier<T> n, String k) => n.addListener(() {
        final v = n.value;
        if (v is bool) { p.setBool(k, v); }
        else if (v is int) { p.setInt(k, v); }
        else if (v is double) { p.setDouble(k, v); }
        else if (v is String) { p.setString(k, v); }
      });
  themeModeNotifier.addListener(() => p.setInt('hs_theme', themeModeNotifier.value.index));
  accentNotifier.addListener(() => p.setInt('hs_accent', accentNotifier.value.toARGB32()));
  b(localeNotifier, 'hs_locale');
  b(oledModeNotifier, 'hs_oled');
  b(hapticFeedbackNotifier, 'hs_haptic'); b(navLabelNotifier, 'hs_navlabels');
  b(textScaleNotifier, 'hs_textscale'); b(appFontNotifier, 'hs_font');
  b(profileNameNotifier, 'hs_name'); b(profileHeightNotifier, 'hs_height');
  b(profileWeightNotifier, 'hs_weight'); b(profileBirthNotifier, 'hs_birthdate');
  b(profileSexNotifier, 'hs_sex'); b(stepGoalNotifier, 'hs_stepgoal');
  b(weeklyGoalNotifier, 'hs_weeklygoal'); b(unitsMetricNotifier, 'hs_metric');
  b(onboardedNotifier, 'hs_onboarded');
  b(sportColorsNotifier, 'hs_sportcolors');
}
