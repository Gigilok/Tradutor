import 'package:flutter/material.dart';

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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Conversa',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Filmes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
