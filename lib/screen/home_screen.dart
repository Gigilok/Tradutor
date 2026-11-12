import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'chat_screen.dart';
import 'movies_screen.dart';
import 'settings_screen.dart';

/// Tela principal com três abas: Conversa, Filmes e Ajustes.
/// Mantém cada aba viva ao alternar (para não perder o chat aberto).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _pages = const [
    ChatScreen(),
    MoviesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: _tab,
        backgroundColor: const Color(0xFF1A1D21),
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: AppStrings.t(context, 'home.chat_tab'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.movie_outlined),
            selectedIcon: const Icon(Icons.movie),
            label: AppStrings.t(context, 'home.movies_tab'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppStrings.t(context, 'home.settings_tab'),
          ),
        ],
      ),
    );
  }
}
