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

    // fallback: generate some food items so swipe UI shows food cards (name + image)
    final foods = [
      {'name': 'Avocado', 'photo': 'asset:assets/images/png/avocado.png'},
      {'name': 'Apple', 'photo': 'asset:assets/images/png/apple.png'},
      {'name': 'Chicken', 'photo': 'asset:assets/images/png/chicken.png'},
      {'name': 'Salad', 'photo': 'asset:assets/images/png/salad.png'},
      {'name': 'Banana', 'photo': 'asset:assets/images/png/banana.png'},
      {'name': 'Bread', 'photo': 'asset:assets/images/png/bread.png'},
    ];

    final fallback = foods
        .asMap()
        .entries
        .map((e) => Profile(
              id: 'food${e.key}',
              name: e.value['name']!,
              age: null,
              bio: 'Tasty ${e.value['name']}',
              photos: [e.value['photo']!],
              interests: const [],
            ))
        .toList()
        .reversed
        .toList();

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
