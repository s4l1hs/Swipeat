import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/profile.dart';
import 'pages/swipe_screen.dart';
import 'pages/subscription_page.dart';
import 'pages/plan_overview.dart';
import 'pages/settings_page.dart';

/// Main app shell with bottom navigation.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  String _idToken = '';

  @override
  void initState() {
    super.initState();
    _loadIdToken();
  }

  Future<void> _loadIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        setState(() {
          _idToken = token ?? '';
        });
      } catch (_) {
        // If token fetch fails, keep an empty token; SubscriptionPage should handle it.
      }
    }
  }

  Profile _buildMe() {
    final user = FirebaseAuth.instance.currentUser;
    return Profile(
      id: user?.uid ?? 'anon',
      name: user?.displayName ?? 'You',
      age: null,
      bio: '',
      photos: [],
      interests: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = _buildMe();
    final pages = <Widget>[
      SwipeScreen(me: me),
      const PlanOverviewScreen(targetCalories: 2000),
      SubscriptionPage(idToken: _idToken),
      const SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selected]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected,
        onTap: (i) => setState(() => _selected = i),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.card_membership), label: 'Subscriptions'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

