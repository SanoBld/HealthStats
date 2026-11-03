// Main navigation: 5 tabs (like LastStats).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../widgets/hs_widgets.dart' show isFr;
import '../widgets/scroll_status_bar.dart';
import '../theme/m3_motion.dart';
import 'activities_page.dart';
import 'charts_page.dart';
import 'dashboard_page.dart';
import '../services/health_service.dart';
import 'map_page.dart';
import 'search_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  @override
  void initState() { super.initState(); localeNotifier.addListener(_r); hiddenTabsNotifier.addListener(_r); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); localeNotifier.removeListener(_r); hiddenTabsNotifier.removeListener(_r); super.dispose(); }
  // Fresh steps when you come back to the app (at most every 5 min)
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    final hs = HealthService.instance;
    // back from Health Connect: re-read which permissions are granted now
    if (st == AppLifecycleState.resumed) { hs.refreshStatus(); }
    if (st == AppLifecycleState.resumed && hs.permitted &&
        (hs.lastSync == null || DateTime.now().difference(hs.lastSync!).inMinutes >= 5)) { hs.sync(); }
  }
  void _r() => setState(() {});
  // index in the full tab list (0 dash, 1 activities, 2 map, 3 search, 4 charts) -> index of the visible tabs
  int _visIndex(int full) {
    const keys = ['dash', 'activities', 'map', 'search', 'charts'];
    final vis = [for (final k in keys) if (k == 'dash' || !isHidden(hiddenTabsNotifier, k)) k];
    final i = vis.indexOf(keys[full.clamp(0, 4)]);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    // (key, page, destination); the dashboard is always there, the others can be hidden in settings
    final all = <(String, Widget, NavigationDestination)>[
      ('dash', DashboardPage(onOpenTab: (i) => setState(() => _idx = _visIndex(i))),
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard_rounded), label: L.navDashboard)),
      ('activities', const ActivitiesPage(),
          NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), selectedIcon: const Icon(Icons.fitness_center_rounded), label: L.navActivities)),
      ('map', const MapPage(),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map_rounded), label: L.navMap)),
      ('search', const SearchPage(),
          NavigationDestination(icon: const Icon(Icons.search_rounded), selectedIcon: const Icon(Icons.search_rounded), label: isFr ? 'Recherche' : 'Search')),
      ('charts', const ChartsPage(),
          NavigationDestination(icon: const Icon(Icons.auto_graph_outlined), selectedIcon: const Icon(Icons.auto_graph_rounded), label: L.navCharts)),
    ];
    final vis = [for (final e in all) if (e.$1 == 'dash' || !isHidden(hiddenTabsNotifier, e.$1)) e];
    final idx = _idx.clamp(0, vis.length - 1);
    final pages = [for (final e in vis) ClipRect(child: ColoredBox(color: bg, child: e.$2))];
    return Scaffold(
      body: ScrollStatusBarHost(
        color: bg,
        resetToken: idx,
        threshold: 0,
        child: M3FadeThroughStack(index: idx, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          if (hapticFeedbackNotifier.value) HapticFeedback.selectionClick();
          setState(() => _idx = i);
        },
        destinations: [for (final e in vis) e.$3],
      ),
    );
  }
}
