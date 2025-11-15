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
   Future<void> _performSwipe(Profile p, bool liked) async {
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
       // notify user about network error
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Network error — could not send swipe.')),
       );
       return;
     }
 
    // NOTE: removed success SnackBar ("Liked"/"Skipped") per UX request.
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
 
    // NOTE: removed success SnackBar ("Restored ...") per UX request.
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
 
   // nicer action button used instead of plain ElevatedButton
   final Set<String> _pressedButtons = {};
   Widget _actionButton({
     required String id,
     required Gradient gradient,
     required IconData icon,
     required VoidCallback onTap,
     double diameter = 64,
     double iconSize = 28,
     Color? fg = Colors.white,
   }) {
     final pressed = _pressedButtons.contains(id);
     return GestureDetector(
       onTapDown: (_) => setState(() => _pressedButtons.add(id)),
       onTapUp: (_) {
         setState(() => _pressedButtons.remove(id));
         onTap();
       },
       onTapCancel: () => setState(() => _pressedButtons.remove(id)),
       child: AnimatedScale(
         scale: pressed ? 0.94 : 1.0,
         duration: const Duration(milliseconds: 120),
         curve: Curves.easeOut,
         child: Container(
           width: diameter.w,
           height: diameter.w,
           decoration: BoxDecoration(
             gradient: gradient,
             shape: BoxShape.circle,
             boxShadow: [
               BoxShadow(color: Colors.black26, blurRadius: 14, offset: const Offset(0, 8)),
             ],
           ),
           child: Center(child: Icon(icon, color: fg, size: iconSize.w)),
         ),
       ),
     );
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
                   // Left: red X -> nicer look
                   _actionButton(
                     id: 'dislike',
                     gradient: const LinearGradient(colors: [Color(0xFFFF7A7A), Color(0xFFFF5252)]),
                     icon: Icons.close,
                     diameter: 64,
                     iconSize: 28,
                     onTap: visibleItems.isNotEmpty ? () => (_swipeKey.currentState as dynamic)?.swipeTop(false) : () {},
                   ),
 
                   // Center: undo (subtle neutral style)
                   _actionButton(
                     id: 'undo',
                     gradient: LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200]),
                     icon: Icons.undo,
                     diameter: 56,
                     iconSize: 26,
                     fg: Colors.black87,
                     onTap: _swipeHistory.isNotEmpty ? () => _onUndoPressed() : () {},
                   ),
 
                   // Right: like (heart)
                   _actionButton(
                     id: 'like',
                     gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6EE7B7), Color(0xFF34D399)]),
                     icon: Icons.favorite,
                     diameter: 64,
                     iconSize: 26,
                     onTap: visibleItems.isNotEmpty ? () => (_swipeKey.currentState as dynamic)?.swipeTop(true) : () {},
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
