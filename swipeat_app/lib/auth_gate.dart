import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_page.dart';
import 'screens/mandatory_profile.dart';
import 'main_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final firebaseConfigured = !(kIsWeb && (opts.apiKey.isEmpty || opts.appId.isEmpty));

    // If Firebase isn't configured for web, don't call FirebaseAuth APIs (they
    // throw). Instead, show the LoginPage which itself will show a friendly
    // error if user tries to sign in.
    if (!firebaseConfigured) {
      return const LoginPage();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        if (!snapshot.hasData) return const LoginPage();

        final user = snapshot.data!;

        // Check backend whether profile is complete and route appropriately.
        return FutureBuilder<bool>(
          future: _isProfileComplete(user),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
            if (snap.hasError) return Scaffold(body: Center(child: Text('Error checking profile: ${snap.error}')));

            final complete = snap.data ?? false;
            if (!complete) {
              // show mandatory profile screen
              return FutureBuilder<String?>(
                future: user.getIdToken(),
                builder: (context, tokenSnap) {
                  if (tokenSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
                  final token = tokenSnap.data;
                  if (token == null) return const LoginPage();
                  return MandatoryProfileScreen(idToken: token, displayName: user.displayName);
                },
              );
            }

            // profile complete -> navigate to main app shell
            return const MainScreen();
          },
        );
      },
    );
  }

  Future<bool> _isProfileComplete(User user) async {
    try {
      final token = await user.getIdToken();
      final uri = Uri.parse('$backendBaseUrl/api/me');
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      final hasName = (data['name'] != null && (data['name'] as String).isNotEmpty);
      final hasAge = data['age'] != null;
      final hasGender = data['gender'] != null || (data['interests'] is List && (data['interests'] as List).any((e) => (e as String).startsWith('gender:')));
      final hasInterested = data['interestedIn'] != null || (data['interests'] is List && (data['interests'] as List).any((e) => (e as String).startsWith('interested:')));

      return hasName && hasAge && hasGender && hasInterested;
    } catch (e) {
      return false;
    }
  }
}
