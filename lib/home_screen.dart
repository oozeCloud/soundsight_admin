import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'challenges_screen.dart';
import 'fundamentals_screen.dart';
import 'pieces_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
    final pages = [
      const ChallengesScreen(),
      const FundamentalsScreen(),
      const PiecesScreen(),
      const UsersScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Material(
              color: const Color(0xFFF8FAFC),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'SoundSight Admin',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(email),
                    ),
                    const SizedBox(height: 16),
                    _SidebarTile(
                      selected: _selectedIndex == 0,
                      icon: Icons.flag_outlined,
                      title: 'Challenges',
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                    _SidebarTile(
                      selected: _selectedIndex == 1,
                      icon: Icons.menu_book_outlined,
                      title: 'Fundamentals',
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    _SidebarTile(
                      selected: _selectedIndex == 2,
                      icon: Icons.library_music_outlined,
                      title: 'Pieces',
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                    _SidebarTile(
                      selected: _selectedIndex == 3,
                      icon: Icons.people_outline,
                      title: 'Users',
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign out'),
                      onTap: FirebaseAuth.instance.signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: const Color(0xFFEFF6FF),
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
