import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/player_service.dart';
import '../widgets/mini_player.dart';
import 'playlists_screen.dart';
import 'all_audios_screen.dart';
import 'add_audio_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PlayerService _player = PlayerService();

  final List<Widget> _screens = const [
    PlaylistsScreen(),
    AllAudiosScreen(),
    AddAudioScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedIndex != 2) MiniPlayer(player: _player),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  height: 60,
                  labelTextStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 11),
                  ),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.queue_music_outlined, size: 22),
                      selectedIcon: Icon(Icons.queue_music, size: 22),
                      label: 'Biblioteca',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search, size: 22),
                      selectedIcon: Icon(Icons.search, size: 22),
                      label: 'Buscar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.add_circle_outline, size: 22),
                      selectedIcon: Icon(Icons.add_circle, size: 22),
                      label: 'Añadir',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined, size: 22),
                      selectedIcon: Icon(Icons.settings, size: 22),
                      label: 'Ajustes',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
