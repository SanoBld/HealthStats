// lib/main.dart — HealthStats (Android). Thème Nothing OS repris de LastStats.
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'nothing_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/health_service.dart';
import 'services/update_service.dart';
import 'theme/m3_interaction.dart';
import 'theme/m3_motion.dart';
import 'theme/m3_shapes.dart';
import 'widgets/app_text_scale.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await loadAppState();
  bindPersistence(await SharedPreferences.getInstance());
  await UpdateService.init();
  HealthService.instance.init(); // non bloquant : le cache s'affiche d'abord
  runApp(const HealthStatsApp());
}

class HealthStatsApp extends StatelessWidget {
  const HealthStatsApp({super.key});

  ThemeData _fin(ThemeData t, bool labels) => t.copyWith(
        pageTransitionsTheme: kM3PageTransitions,
        navigationBarTheme: t.navigationBarTheme.copyWith(
            labelBehavior: labels
                ? NavigationDestinationLabelBehavior.alwaysShow
                : NavigationDestinationLabelBehavior.alwaysHide));

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDyn, darkDyn) {
      return ListenableBuilder(
        listenable: Listenable.merge([
          themeStyleNotifier, nothingAccentNotifier, themeModeNotifier, localeNotifier,
          navLabelNotifier, accentNotifier, useDynamicColorNotifier, oledModeNotifier,
          onboardedNotifier,
        ]),
        builder: (_, _) {
          final labels = navLabelNotifier.value;
          late ThemeData light, dark;
          if (themeStyleNotifier.value == 'nothing') {
            light = _fin(NothingTheme.build(accent: nothingAccentNotifier.value, brightness: Brightness.light), labels);
            dark = _fin(NothingTheme.build(accent: nothingAccentNotifier.value, brightness: Brightness.dark), labels);
          } else {
            final dyn = useDynamicColorNotifier.value;
            final seed = accentNotifier.value;
            ColorScheme ls = (dyn && lightDyn != null) ? lightDyn.harmonized() : ColorScheme.fromSeed(seed: seed);
            ColorScheme ds = (dyn && darkDyn != null)
                ? darkDyn.harmonized()
                : ColorScheme.fromSeed(seed: seed, brightness: Brightness.dark);
            if (oledModeNotifier.value) {
              ds = ds.copyWith(surface: Colors.black, surfaceContainerLowest: Colors.black,
                  surfaceContainerLow: const Color(0xFF080808), surfaceContainer: const Color(0xFF0D0D0D));
            }
            light = _fin(applyM3Interaction(applyM3Shapes(ThemeData(colorScheme: ls, useMaterial3: true))), labels);
            dark = _fin(applyM3Interaction(applyM3Shapes(ThemeData(colorScheme: ds, useMaterial3: true))), labels);
          }
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'HealthStats',
            debugShowCheckedModeBanner: false,
            theme: light, darkTheme: dark, themeMode: themeModeNotifier.value,
            builder: (c, child) => AppTextScale(child: child!),
            home: onboardedNotifier.value ? const HomeScreen() : const OnboardingScreen(),
          );
        },
      );
    });
  }
}
