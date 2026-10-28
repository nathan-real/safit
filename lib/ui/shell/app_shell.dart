import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/results/results_screen.dart';
import '../screens/tests/tests_screen.dart';

enum AppTab { home, tests, results, profile }

/// Coque de l'app : les 4 onglets + la barre de navigation du bas.
/// Les onglets sont gardés en vie (IndexedStack) pour conserver leur état.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Permet à un écran de changer d'onglet (ex. « Nouveau test » → Tests).
  static AppShellState of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>()!;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;

  void goTo(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    // Le bouton retour Android ramène d'abord à l'accueil avant de quitter.
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: const [
            HomeScreen(),
            TestsScreen(),
            ResultsScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => goTo(AppTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_bike_outlined),
              selectedIcon: Icon(Icons.directions_bike),
              label: 'Tests',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Résultats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
