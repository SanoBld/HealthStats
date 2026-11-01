// Main navigation: 5 tabs (like LastStats).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../theme/m3_motion.dart';
import 'activities_page.dart';
import 'charts_page.dart';
import 'dashboard_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  @override
  void initState() { super.initState(); localeNotifier.addListener(_r); }
  @override
  void dispose() { localeNotifier.removeListener(_r); super.dispose(); }
  void _r() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onOpenTab: (i) => setState(() => _idx = i)),
      const ActivitiesPage(), const MapPage(), const ChartsPage(), const SettingsPage(),
    ];
    return Scaffold(
      body: M3FadeThroughStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) {
          if (hapticFeedbackNotifier.value) HapticFeedback.selectionClick();
          setState(() => _idx = i);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard_rounded), label: L.navDashboard),
          NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), selectedIcon: const Icon(Icons.fitness_center_rounded), label: L.navActivities),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: L.navMap),
          NavigationDestination(icon: const Icon(Icons.auto_graph_outlined), selectedIcon: const Icon(Icons.auto_graph_rounded), label: L.navCharts),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings_rounded), label: L.navSettings),
        ],
      ),
    );
  }
}
