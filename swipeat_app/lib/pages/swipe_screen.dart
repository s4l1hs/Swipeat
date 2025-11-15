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

class _SwipedAction {
  final Profile profile;
  final bool liked;
  _SwipedAction(this.profile, this.liked);
}

class _SwipeScreenState extends State<SwipeScreen> with TickerProviderStateMixin {
   // simple local candidate list
   late List<Profile> candidates;
 
   // API service instance
   late ApiService _api_service;
 
   // history of swiped items for undo
   final List<_SwipedAction> _swipeHistory = [];

  // SwipeStack key to call programmatic swipe/restore methods
  final GlobalKey _swipeKey = GlobalKey();

   @override
   void initState() {
     super.initState();
     candidates = [];
     _api_service = ApiService();
     _loadCandidates();
   }
 
   @override
   void dispose() {
    super.dispose();
   }
 
   // unified swipe handler (used by SwipeStack gestures and programmatic swipeTop)
   Future<void> _performSwipe(Profile p, bool liked, {bool showSnack = true}) async {
     // optimistic local update: remove from candidates and push to history
     _swipeHistory.add(_SwipedAction(p, liked));
     setState(() => candidates.remove(p));
 
     // call backend and await result; if it fails, restore locally and rethrow/log
     try {
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
         final token = await user.getIdToken();
         if (token != null && token.isNotEmpty) {
          debugPrint('SwipeScreen: sending swipe to backend for ${p.id} liked=$liked');
          await _api_service.swipeProfile(token, p.id, liked ? 'like' : 'dislike');
          debugPrint('SwipeScreen: swipe sent for ${p.id} liked=$liked');
         }
       }
     } catch (e) {
       // rollback local optimistic change
       debugPrint('Swipe POST failed, restoring card: $e');
       // remove last history entry if it corresponds to this profile
       if (_swipeHistory.isNotEmpty && _swipeHistory.last.profile.id == p.id) {
         _swipeHistory.removeLast();
       }
       setState(() => candidates.add(p));
       // notify user
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Network error — could not send swipe.')),
       );
       return;
     }
 
     if (showSnack) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('${liked ? 'Liked' : 'Skipped'} ${p.name}')),
       );
     }
   }
 
   // called from SwipeStack user swipes
   void _onSwipe(Profile p, bool liked) {
     // ensure backend is called for gesture swipes as well
     _performSwipe(p, liked);
   }
 
  // Programmatic undo triggered from button: insert profile on top,
  // ask SwipeStack to animate restoreFromSide, then remove history + call backend undo.
  Future<void> _onUndoPressed() async {
    if (_swipeHistory.isEmpty) return;

    final last = _swipeHistory.last;
    final prof = last.profile;
    final fromRight = last.liked;

    // restore into parent list so SwipeStack sees it as top
    setState(() => candidates.add(prof));
    // give frame for SwipeStack.didUpdateWidget -> sync
    await Future.delayed(const Duration(milliseconds: 20));

    // animate using SwipeStack's method (same animation as gesture)
    await (_swipeKey.currentState as dynamic)?.restoreTopFromSide(prof, fromRight);

    // remove history and call backend undo
    _swipeHistory.removeLast();
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : null;
      if (token != null && token.isNotEmpty) {
        await _api_service.undoSwipe(token, prof.id);
      }
    } catch (e) {
      debugPrint('backend undo failed: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored ${prof.name}')));
  }
 
   Future<void> _loadCandidates() async {
     try {
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
         final token = await user.getIdToken();
         if (token == null || token.isEmpty) throw Exception('No id token');
         final raw = await _api_service.getNextCandidates(token, limit: 20);
 
         // Map backend payload -> Profile list
         final list = raw
             .map((m) => Profile(
                   id: m['uid'] as String? ?? (m['id'] as String?) ?? '',
                   name: m['name'] as String? ?? 'Anon',
                   age: m['age'] != null ? (m['age'] as num).toInt() : null,
                   bio: m['bio'] as String?,
                   photos: (m['photos'] is List) ? List<String>.from(m['photos']) : [],
                   interests: (m['interests'] is List) ? List<String>.from(m['interests']) : [],
                 ))
             .toList();
 
         // If backend returned nothing or only placeholder "Candidate-..." names,
         // prefer local fallback so UI shows food emojis & colors as intended.
         final hasReal = list.isNotEmpty && list.any((p) => !(p.name.startsWith('Candidate-') || p.name.startsWith('candidate-')));
         if (!hasReal) {
           debugPrint('_loadCandidates: backend empty or placeholders only -> using local fallback');
           // fallback: explicit food names in preferred order (top = last element)
           final foods = [
             {'id': 'food0', 'name': 'Avocado'},
             {'id': 'food1', 'name': 'Apple'},
             {'id': 'food2', 'name': 'Chicken'},
             {'id': 'food3', 'name': 'Salad'},
             {'id': 'food4', 'name': 'Banana'},
             {'id': 'food5', 'name': 'Bread'},
           ];
           final fallback = foods
               .map((e) => Profile(
                     id: e['id']!,
                     name: e['name']!,
                     age: null,
                     bio: e['name'],
                     photos: const [],
                     interests: const [],
                   ))
               .toList()
               .reversed
               .toList(); // keep top as last to match existing logic using candidates.last
 
           setState(() => candidates = fallback);
           return;
         }
 
         // Backend returned real profiles — keep them but ensure order matches UI expectations
         // (we keep reversed so last item is top, consistent with _performSwipe/candidates.last usage)
         setState(() => candidates = list.reversed.toList());
         return;
       }
     } catch (e) {
       debugPrint('Could not fetch candidates from backend: $e');
     }
 
     // Fallback if no auth or request failed: local food items (same as above)
     final foods = [
       {'id': 'food0', 'name': 'Avocado'},
       {'id': 'food1', 'name': 'Apple'},
       {'id': 'food2', 'name': 'Chicken'},
       {'id': 'food3', 'name': 'Salad'},
       {'id': 'food4', 'name': 'Banana'},
       {'id': 'food5', 'name': 'Bread'},
     ];
 
     final fallback = foods
         .map((e) => Profile(
               id: e['id']!,
               name: e['name']!,
               age: null,
               bio: e['name'],
               photos: const [], // no image assets used
               interests: const [],
             ))
         .toList()
         .reversed
         .toList();
 
     setState(() => candidates = fallback);
   }
 
   @override
   Widget build(BuildContext context) {
    final visibleItems = List<Profile>.from(candidates);
 
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
                   child: visibleItems.isEmpty
                       ? const Text('No more profiles')
                      : SwipeStack(
                          key: _swipeKey,
                          items: visibleItems,
                          onSwipe: (p, liked) => _onSwipe(p, liked),
                        ),
                 ),
               ),
 
               SizedBox(height: 12.h),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   // Left: red X -> act like left swipe (dislike)
                   ElevatedButton(
                     // DÜZELTME: Artık 'visibleItems.last' (görünen kart)
                     // neyse onu hedef alarak eylemi tetikliyor.
                     onPressed: visibleItems.isNotEmpty
                        ? () {
                            (_swipeKey.currentState as dynamic)?.swipeTop(false);
                          }
                         : null,
                     style: ElevatedButton.styleFrom(
                       shape: const CircleBorder(),
                       backgroundColor: Colors.red,
                       minimumSize: Size(56.w, 56.w),
                     ),
                     child: Icon(Icons.close, color: Colors.white, size: 28.w),
                   ),
 
                   // Center: undo (Bu zaten doğru, _swipeHistory'i kontrol ediyor)
                   ElevatedButton(
                     onPressed: _swipeHistory.isNotEmpty ? () => _onUndoPressed() : null,
                     // ... (bu butonun kalanı aynı)
                     style: ElevatedButton.styleFrom(
                       shape: const CircleBorder(),
                       backgroundColor: Colors.grey.shade200,
                       minimumSize: Size(56.w, 56.w),
                       elevation: 0,
                     ),
                     child: Icon(Icons.undo, color: Colors.black87, size: 26.w),
                   ),
 
                   // Right: green heart -> act like right swipe (like)
                   ElevatedButton(
                     onPressed: visibleItems.isNotEmpty
                        ? () {
                            (_swipeKey.currentState as dynamic)?.swipeTop(true);
                          }
                         : null,
                     style: ElevatedButton.styleFrom(
                       shape: const CircleBorder(),
                       backgroundColor: Colors.green,
                       minimumSize: Size(56.w, 56.w),
                     ),
                     child: Icon(Icons.favorite, color: Colors.white, size: 26.w),
                   ),
                 ],
               ),
 
               SizedBox(height: 12.h),
             ],
           ),
         ),
       ),
     );
   }
 }
