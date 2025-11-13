import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/profile.dart';
import '../widgets/swipe_stack.dart';

class SwipeScreen extends StatefulWidget {
  final Profile me;
  const SwipeScreen({required this.me, super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}



class _SwipeScreenState extends State<SwipeScreen> {
  // simple local candidate list
  late List<Profile> candidates;

  @override
  void initState() {
    super.initState();
    candidates = [];
    _apiService = ApiService();
    _loadCandidates();
  }

  late final ApiService _apiService;

  Future<void> _loadCandidates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
  if (token == null || token.isEmpty) throw Exception('No id token');
  final raw = await _apiService.getNextCandidates(token, limit: 20);
        final list = raw.map((m) => Profile(
              id: m['uid'] as String? ?? (m['id'] as String?) ?? '',
              name: m['name'] as String? ?? 'Anon',
              age: m['age'] != null ? (m['age'] as num).toInt() : null,
              bio: m['bio'] as String?,
              photos: (m['photos'] is List) ? List<String>.from(m['photos']) : [],
              interests: (m['interests'] is List) ? List<String>.from(m['interests']) : [],
            ))
            .toList()
            .reversed
            .toList();
        setState(() => candidates = list);
        return;
      }
    } catch (e) {
      debugPrint('Could not fetch candidates from backend: $e');
    }

    // fallback: generate some dummy candidates so onboarding still works offline
    final fallback = List.generate(6, (i) {
      return Profile(
        id: 'c$i',
        name: 'Person ${i + 1}',
        age: 20 + i,
        bio: 'Loves design, music and long walks.',
        photos: [],
        interests: ['music', 'design'],
      );
    }).reversed.toList();
    setState(() => candidates = fallback);
  }

  void _onSwipe(Profile p, bool liked) {
    setState(() => candidates.remove(p));
    // send swipe to backend if possible
    () async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null && token.isNotEmpty) {
            await _apiService.swipeProfile(token, p.id, liked ? 'like' : 'dislike');
          }
        }
      } catch (e) {
        debugPrint('Swipe POST failed: $e');
      }
    }();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${liked ? 'Liked' : 'Skipped'} ${p.name}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar title — keep screen focused on the cards only
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // small spacer so the cards sit a bit lower on the screen (global app bar above)
                SizedBox(height: 20.h),

              Expanded(
                child: Center(
                  child: candidates.isEmpty
                      ? const Text('No more profiles')
                      : SwipeStack(
                          items: candidates,
                          onSwipe: (p, liked) => _onSwipe(p, liked),
                        ),
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
