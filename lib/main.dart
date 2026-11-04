// lib/main.dart — HealthStats (Android).
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/health_service.dart';
import 'services/update_service.dart';
import 'theme/m3_interaction.dart';
import 'theme/m3_motion.dart';
import 'theme/m3_shapes.dart';
import 'theme/app_scheme.dart';
import 'widgets/app_text_scale.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await loadAppState();
  bindPersistence(await SharedPreferences.getInstance());
  await UpdateService.init();
  HealthService.instance.init(); // non-blocking: the cache is shown first
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
          themeModeNotifier, localeNotifier,
          navLabelNotifier, accentNotifier, useDynamicColorNotifier, colorHarmonyNotifier, oledModeNotifier,
          onboardedNotifier,
        ]),
        builder: (_, _) {
          final labels = navLabelNotifier.value;
          final dyn = useDynamicColorNotifier.value;
          final seed = accentNotifier.value;
          final harmony = colorHarmonyNotifier.value;
          final ColorScheme ls = (dyn && lightDyn != null)
              ? applyColorHarmony(neutralizeIfGraySchemeItself(lightDyn.harmonized()), harmony)
              : buildAppScheme(seed, Brightness.light, harmony);
          ColorScheme ds = (dyn && darkDyn != null)
              ? applyColorHarmony(neutralizeIfGraySchemeItself(darkDyn.harmonized()), harmony)
              : buildAppScheme(seed, Brightness.dark, harmony);
          if (oledModeNotifier.value) {
            ds = ds.copyWith(
                surface: Colors.black, surfaceDim: Colors.black, surfaceBright: const Color(0xFF1C1C1C),
                surfaceContainerLowest: Colors.black, surfaceContainerLow: const Color(0xFF080808),
                surfaceContainer: const Color(0xFF0D0D0D), surfaceContainerHigh: const Color(0xFF141414),
                surfaceContainerHighest: const Color(0xFF1C1C1C));
            if (harmony == 'tinted') ds = tintNeutrals(ds);
          }
          final light = _fin(applyM3Interaction(applyM3Shapes(ThemeData(colorScheme: ls, useMaterial3: true))), labels);
          final dark = _fin(applyM3Interaction(applyM3Shapes(ThemeData(colorScheme: ds, useMaterial3: true))), labels);
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
