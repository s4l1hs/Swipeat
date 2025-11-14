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
   late ApiService _apiService;
 
   // history of swiped items for undo
   final List<_SwipedAction> _swipeHistory = [];
 
   // IDs to temporarily hide from SwipeStack while overlay animation runs
   final Set<String> _hiddenDuringAnim = {};
 
   // overlay animation controller + entry
   OverlayEntry? _overlayEntry;

   @override
   void initState() {
     super.initState();
     candidates = [];
     _apiService = ApiService();
     _loadCandidates();
   }

   @override
   void dispose() {
     _removeOverlay();
     super.dispose();
   }
 
   void _removeOverlay() {
     final e = _overlayEntry;
     if (e != null) {
       try {
         e.remove();
       } catch (_) {}
       _overlayEntry = null;
     }
   }
 
   Future<void> _animateSwipeOff(Profile p, bool toRight) async {
     if (_overlayEntry != null) return;
     final mq = MediaQuery.of(context);
     final width = mq.size.width;
     final cardWidth = width * 0.86;
     final cardHeight = mq.size.height * 0.62;
     final startX = 0.0;
     final endX = (toRight ? width * 1.2 : -width * 1.2);
 
     final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
     final animX = Tween<double>(begin: startX, end: endX).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));
     final animRot = Tween<double>(begin: 0.0, end: (toRight ? 0.25 : -0.25)).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));
 
     _overlayEntry = OverlayEntry(builder: (_) {
       return Positioned.fill(
         child: IgnorePointer(
           ignoring: true,
           child: AnimatedBuilder(
             animation: controller,
             builder: (_, __) {
               return Transform.translate(
                 offset: Offset(animX.value, 0),
                 child: Center(
                   child: Transform.rotate(
                     angle: animRot.value,
                     child: SizedBox(
                       width: cardWidth,
                       height: cardHeight,
                       child: _buildAnimatedCard(p),
                     ),
                   ),
                 ),
               );
             },
           ),
         ),
       );
     });
 
     Overlay.of(context).insert(_overlayEntry!);
     try {
       await controller.forward();
     } finally {
       // always dispose local controller and remove overlay
       controller.dispose();
       _removeOverlay();
     }
   }
 
   Future<void> _animateRestoreFromSide(Profile p, bool fromRight) async {
     if (_overlayEntry != null) return;
     final mq = MediaQuery.of(context);
     final width = mq.size.width;
     final cardWidth = width * 0.86;
     final cardHeight = mq.size.height * 0.62;
     final startX = (fromRight ? width * 1.2 : -width * 1.2);
     final endX = 0.0;
 
     final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
     final animX = Tween<double>(begin: startX, end: endX).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
     final startRot = (fromRight ? 0.25 : -0.25);
     final animRot = Tween<double>(begin: startRot, end: 0.0).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
 
     _overlayEntry = OverlayEntry(builder: (_) {
       return Positioned.fill(
         child: IgnorePointer(
           ignoring: true,
           child: AnimatedBuilder(
             animation: controller,
             builder: (_, __) {
               return Transform.translate(
                 offset: Offset(animX.value, 0),
                 child: Center(
                   child: Transform.rotate(
                     angle: animRot.value,
                     child: SizedBox(
                       width: cardWidth,
                       height: cardHeight,
                       child: _buildAnimatedCard(p),
                     ),
                   ),
                 ),
               );
             },
           ),
         ),
       );
     });
 
     Overlay.of(context).insert(_overlayEntry!);
     try {
       await controller.forward();
     } finally {
       controller.dispose();
       _removeOverlay();
     }
   }
 
   // Small helper to build the animated card UI used for overlay animation.
   // Keep consistent with SwipeStack card visuals (emoji + background).
   Widget _buildAnimatedCard(Profile p) {
     // Per-food visuals mapping used elsewhere; fallback simple color/emoji
     final visuals = <String, Map<String, dynamic>>{
       'Avocado': {'emoji': '🥑', 'color': const Color(0xFF86C166)},
       'Apple': {'emoji': '🍎', 'color': const Color(0xFFE53935)},
       'Banana': {'emoji': '🍌', 'color': const Color(0xFFFFEB3B)},
       'Bread': {'emoji': '🍞', 'color': const Color(0xFFD7A36E)},
       'Chicken': {'emoji': '🍗', 'color': const Color(0xFFFFAB91)},
       'Salad': {'emoji': '🥗', 'color': const Color(0xFF8BC34A)},
     };
     final v = visuals[p.name] ?? {'emoji': '🍽️', 'color': Colors.grey.shade300};
     final emoji = v['emoji'] as String;
     final color = v['color'] as Color;
 
     // Card sized approx same as in SwipeStack
     final cardWidth = MediaQuery.of(context).size.width * 0.86;
     final cardHeight = MediaQuery.of(context).size.height * 0.62;
 
     return Center(
       child: Container(
         width: cardWidth,
         height: cardHeight,
         decoration: BoxDecoration(
           color: color,
           borderRadius: BorderRadius.circular(16),
           boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 12, offset: Offset(0, 6))],
         ),
         child: Center(
           child: Text(emoji, style: TextStyle(fontSize: 120.sp)),
         ),
       ),
     );
   }
 
   // unified swipe handler (used by UI & buttons)
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
           await _apiService.swipeProfile(token, p.id, liked ? 'like' : 'dislike');
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
 
   // The previous _undoLastSwipe helper was removed because it's unused;
   // use _undoButtonAction() for user-triggered undo or undoLastSwipeProgrammatic()
   // for programmatic restores which already handle local restore + backend undo.
 
   // wrapper called by left/right buttons to animate then perform swipe (backend)
   Future<void> _swipeButtonAction(bool liked) async {
     if (candidates.isEmpty || _overlayEntry != null) return;

     final top = candidates.last;

     // hide underlying top card while overlay animates
     setState(() => _hiddenDuringAnim.add(top.id));

     try {
       // Animate off (with rotation)
       await _animateSwipeOff(top, liked);

       // After animation finished -> perform removal + backend call
       // This ensures the card does not remain visible in the center
       await _performSwipe(top, liked);
     } finally {
       // Always remove hidden flag so stack can re-render (if card removed it's fine)
       setState(() => _hiddenDuringAnim.remove(top.id));
     }
   }
 
   // wrapper for undo button: restore on top (hidden), animate from side above all, then unhide + backend undo
   Future<void> _undoButtonAction() async {
     if (_swipeHistory.isEmpty || _overlayEntry != null) return;
 
     final last = _swipeHistory.last; // peek
     final prof = last.profile;
     final fromRight = last.liked;
 
     // Restore into local list on top but keep it hidden while overlay animates
     setState(() {
       candidates.add(prof);
       _hiddenDuringAnim.add(prof.id);
     });
 
     // Animate card coming from the side (rotation returns to 0)
     await _animateRestoreFromSide(prof, fromRight);
 
     // Unhide so SwipeStack shows the restored card on top
     setState(() => _hiddenDuringAnim.remove(prof.id));
 
     // Remove history entry (we consider restored now)
     _swipeHistory.removeLast();
 
     // Fire backend undo (non-blocking for UX)
     try {
       final user = FirebaseAuth.instance.currentUser;
       final token = user != null ? await user.getIdToken() : null;
       if (token != null && token.isNotEmpty) {
         await _apiService.undoSwipe(token, prof.id);
       }
     } catch (e) {
       debugPrint('backend undo failed: $e');
     }
 
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored ${prof.name}')));
   }
 
   // simplified undo API for programmatic undo (used elsewhere if needed)
   Future<void> undoLastSwipeProgrammatic() async {
     if (_swipeHistory.isEmpty) return;
     await _undoButtonAction();
   }
 
   Future<void> _loadCandidates() async {
     try {
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
         final token = await user.getIdToken();
         if (token == null || token.isEmpty) throw Exception('No id token');
         final raw = await _apiService.getNextCandidates(token, limit: 20);
 
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
     // Filter out hidden IDs so SwipeStack doesn't render them during overlay animation
     final visibleItems = candidates.where((p) => !_hiddenDuringAnim.contains(p.id)).toList();
 
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
                           items: visibleItems,
                           onSwipe: (p, liked) => _onSwipe(p, liked),
                         ),
                 ),
               ),
 
               // action buttons row: left X, undo, right heart
               SizedBox(height: 12.h),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   // Left: red X -> act like left swipe (dislike)
                   ElevatedButton(
                     onPressed: candidates.isNotEmpty && _overlayEntry == null ? () => _swipeButtonAction(false) : null,
                     style: ElevatedButton.styleFrom(
                       shape: const CircleBorder(),
                       backgroundColor: Colors.red,
                       minimumSize: Size(56.w, 56.w),
                     ),
                     child: Icon(Icons.close, color: Colors.white, size: 28.w),
                   ),
 
                   // Center: undo
                   ElevatedButton(
                     onPressed: _swipeHistory.isNotEmpty && _overlayEntry == null ? () => _undoButtonAction() : null,
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
                     onPressed: candidates.isNotEmpty && _overlayEntry == null ? () => _swipeButtonAction(true) : null,
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
