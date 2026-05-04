import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/');
            case 1: context.go('/clients');
            case 2: context.go('/procedures');
            case 3: context.go('/cashflow');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa), label: 'Serviços'),
          NavigationDestination(icon: Icon(Icons.attach_money_outlined), selectedIcon: Icon(Icons.attach_money), label: 'Financeiro'),
        ],
      ),
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/clients')) return 1;
    if (location.startsWith('/procedures')) return 2;
    if (location.startsWith('/cashflow') || location.startsWith('/dre')) return 3;
    return 0;
  }
}
