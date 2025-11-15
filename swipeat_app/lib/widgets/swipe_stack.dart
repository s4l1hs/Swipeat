import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/profile.dart';

// Simple visual mapping for foods: emoji and background color
const Map<String, Map<String, dynamic>> _foodVisuals = {
  'avocado': {'emoji': '🥑', 'bg': Color(0xFF86C166)},
  'apple': {'emoji': '🍎', 'bg': Color(0xFFFFE6E6)},
  'banana': {'emoji': '🍌', 'bg': Color(0xFFFFF9E6)},
  'bread': {'emoji': '🥖', 'bg': Color(0xFFFFF4EB)},
  'chicken': {'emoji': '🍗', 'bg': Color(0xFFFFF6E5)},
  'salad': {'emoji': '🥗', 'bg': Color(0xFFE8FFF2)},
};

typedef OnSwipe = void Function(Profile profile, bool liked);

class SwipeStack extends StatefulWidget {
  final List<Profile> items;
  final OnSwipe onSwipe;
  final int maxVisible;
  // Fraction of the width a card must be dragged to count as a swipe (0..1)
  final double swipeThreshold;
  // Multiplier applied to the raw normalized drag to compute rotation
  final double rotationMultiplier;
  // Maximum rotation angle (radians) to clamp rotation to
  final double maxRotation;

  const SwipeStack({
    required this.items,
    required this.onSwipe,
    this.maxVisible = 3,
    this.swipeThreshold = 0.25,
    this.rotationMultiplier = 0.4,
    this.maxRotation = math.pi / 6,
    super.key,
  });

  @override
  State<SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<SwipeStack> with SingleTickerProviderStateMixin {
  late List<Profile> items;
  final List<Map<String, dynamic>> history = [];

  // top card anim state
  Offset _offset = Offset.zero;
  double _rotation = 0.0;

  // yeni: swipe animasyonu için controller/animasyon
  late final AnimationController _swipeController;
  Animation<Offset>? _swipeAnimation;
  bool _isAnimatingOut = false;
  bool _pendingLike = false;
  Profile? _pendingProfile;
  bool _isReturnAnimation = false;

  @override
  void initState() {
    super.initState();
    items = List.of(widget.items);

    // Slightly slower swipe animation for a more aesthetic feel
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _swipeController.addStatusListener(_onSwipeAnimStatus);
  }

  @override
  void didUpdateWidget(covariant SwipeStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync internal items list with parent-provided widget.items
    if (!listEquals(oldWidget.items, widget.items)) {
      setState(() {
        items = List.of(widget.items);
        // reset any transient state to avoid visual mismatch
        _offset = Offset.zero;
        _rotation = 0.0;
        _swipeAnimation = null;
        _isAnimatingOut = false;
        _isReturnAnimation = false;
        _pendingProfile = null;
      });
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    // ...existing dispose code...
    super.dispose();
  }

  void _onSwipeAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final profile = _pendingProfile;
      final liked = _pendingLike;
      if (!_isReturnAnimation) {
        if (profile != null) history.add({'profile': profile, 'liked': liked});
        setState(() {
          if (items.isNotEmpty) items.removeLast();
          _offset = Offset.zero;
          _rotation = 0.0;
          _isAnimatingOut = false;
          _swipeAnimation = null;
          _pendingProfile = null;
        });
        if (profile != null) {
          try {
            widget.onSwipe(profile, liked);
          } catch (_) {}
        }
      } else {
        // return-to-center finished
        setState(() {
          _offset = Offset.zero;
          _rotation = 0.0;
          _isAnimatingOut = false;
          _swipeAnimation = null;
          _isReturnAnimation = false;
          _pendingProfile = null;
        });
      }
    }
  }

  /// Programmatic: animate the current top card out (true = right / like, false = left)
  Future<void> swipeTop(bool liked) async {
    if (items.isEmpty || _isAnimatingOut) return;
    final top = items.last;
    // Start swipe animation
    _performSwipeAnim(top, liked);

    // Await animation completion
    final completer = Completer<void>();
    void listener(AnimationStatus s) {
      if (s == AnimationStatus.completed) completer.complete();
    }

    _swipeController.addStatusListener(listener);
    await completer.future;
    _swipeController.removeStatusListener(listener);
  }

  /// Programmatic: restore the top card visually by animating it from side -> center.
  /// Parent must already have inserted the profile as the top item in widget.items.
  Future<void> restoreTopFromSide(Profile p, bool fromRight) async {
    if (items.isEmpty) return;
    // Ensure the top item matches provided profile
    if (items.last.id != p.id) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final startDx = fromRight ? screenWidth * 1.2 : -screenWidth * 1.2;

    setState(() {
      _offset = Offset(startDx, 0);
      final raw = _offset.dx / 300.0 * widget.rotationMultiplier;
      _rotation = raw.clamp(-widget.maxRotation, widget.maxRotation).toDouble();
      _isReturnAnimation = true;
      _pendingProfile = p;
    });

    // animate from current offset -> center
    final completer = Completer<void>();
    void statusListener(AnimationStatus s) {
      if (s == AnimationStatus.completed) completer.complete();
    }

    _swipeController.addStatusListener(statusListener);
    _swipeController.duration = const Duration(milliseconds: 420);
    _swipeAnimation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut))
      ..addListener(() {
        setState(() {
          _offset = _swipeAnimation!.value;
          final raw = _offset.dx / 300.0 * widget.rotationMultiplier;
          _rotation = raw.clamp(-widget.maxRotation, widget.maxRotation).toDouble();
        });
      });

    _swipeController.reset();
    _swipeController.forward();
    await completer.future;
    _swipeController.removeStatusListener(statusListener);
  }

  void _animateBackToCenter() {
    if (_isAnimatingOut) return;
    _isReturnAnimation = true;
    _swipeController.duration = const Duration(milliseconds: 420);
    _swipeAnimation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut))
      ..addListener(() {
        setState(() {
          _offset = _swipeAnimation!.value;
          final raw = _offset.dx / 300.0 * widget.rotationMultiplier;
          _rotation = (raw.clamp(-widget.maxRotation, widget.maxRotation)).toDouble();
        });
      });
    _swipeController.reset();
    _swipeController.forward();
  }

  // yeni yardımcı: kartı animasyonla dışarı at
  // perform a smooth swipe-out animation for the current top card
  void _performSwipeAnim(Profile top, bool liked) {
    if (_isAnimatingOut) return;
    if (items.isEmpty) return;
    _isReturnAnimation = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = (liked ? 1 : -1) * (screenWidth + 200);
    final begin = _offset;
    final end = Offset(endX, 0); // Y = 0 fixed
    _swipeAnimation = Tween<Offset>(begin: begin, end: end).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() {
          _offset = _swipeAnimation!.value;
          // rotation clamped
          final raw = _offset.dx / 300.0 * widget.rotationMultiplier;
          _rotation = (raw.clamp(-widget.maxRotation, widget.maxRotation)).toDouble();
        });
      });
    _pendingLike = liked;
    _pendingProfile = top;
    _isAnimatingOut = true;
    _swipeController.reset();
    _swipeController.forward();
  }

  // New horizontal-only handlers using HorizontalDragGestureRecognizer
  void _onHorizontalDragStart(DragStartDetails details) {
    // nothing for now, but kept for extensibility (e.g. start velocity tracking)
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      // Restrict movement to the X axis only. Keep Y at 0 so cards don't move up/down.
      _offset = Offset(_offset.dx + d.delta.dx, 0);
      // Compute rotation based on horizontal displacement, apply multiplier and clamp.
  final raw = _offset.dx / 300.0 * widget.rotationMultiplier;
  _rotation = (raw.clamp(-widget.maxRotation, widget.maxRotation)).toDouble();
    });
  }

  void _onHorizontalDragEnd(DragEndDetails e) {
    final width = MediaQuery.of(context).size.width;
    final threshold = width * widget.swipeThreshold;
    // Use velocity as well for fling behavior: if fling is strong horizontally, accept swipe
    final vx = e.velocity.pixelsPerSecond.dx;
    final flingAccepted = vx.abs() > 800; // px/s threshold for a fling
    if (_offset.dx > threshold || (vx > 0 && flingAccepted)) {
      if (items.isNotEmpty) _performSwipeAnim(items.last, true);
    } else if (_offset.dx < -threshold || (vx < 0 && flingAccepted)) {
      if (items.isNotEmpty) _performSwipeAnim(items.last, false);
    } else {
      // return to center
      _animateBackToCenter();
    }
  }

  // Programmatic swipe/undo controls removed — gestures drive the UX exclusively.

  Widget _buildCard(Profile p, {required bool isTop, required double cardWidth, required double cardHeight, required double translate}) {
    // Aesthetic food-card: fixed size, full-bleed image and centered name overlay
    final radius = 18.r;
    return Transform.translate(
      offset: Offset(0, translate),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          elevation: 12,
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // background image (support local SVG assets, raster assets, and network images)
              // Replace raster/SVG/network images with a compact emoji badge + background color per food.
              Positioned.fill(
                child: Builder(builder: (ctx) {
                  final key = p.name.toLowerCase();
                  final visual = _foodVisuals.containsKey(key) ? _foodVisuals[key]! : {'emoji': '🍽️', 'bg': const Color(0xFFEEEEEE)};
                  final Color bg = visual['bg'] as Color;
                  final String emoji = visual['emoji'] as String;
                  return Container(
                    color: bg,
                    child: Stack(
                      children: [
                        // centered big emoji as the clear, primary icon for the card
                        Center(
                          child: Text(
                            emoji,
                            // slightly larger but not so large that it obscures the name overlay
                            style: TextStyle(fontSize: 140.sp),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              // subtle gradient at bottom for text legibility
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: cardHeight * 0.30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.45)],
                    ),
                  ),
                ),
              ),
              // food name centered near bottom
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom: 18.h,
                child: Center(
                  child: Text(
                    p.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8.r, color: Colors.black45, offset: Offset(0, 2.h))],
                    ),
                  ),
                ),
              ),
              // small decorative inner shadow / vignette
                  const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                      decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                            colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.06)],
                            stops: [0.7, 1.0],
                      ),
                    ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = items.length < widget.maxVisible ? items.length : widget.maxVisible;
    final baseWidth = MediaQuery.of(context).size.width * 0.86;
    final baseHeight = MediaQuery.of(context).size.height * 0.64;

    return Column(
      children: [
        SizedBox(
          width: baseWidth,
          height: baseHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // build stack
              for (var i = 0; i < items.length; i++)
                if (i >= items.length - visible) ...[ // show only last N
                  Builder(builder: (ctx) {
                    final depth = i - (items.length - visible);
                    // keep all cards same size for a uniform look
                    final translate = 8.0 * depth; // small stacking offset
                    final isTop = i == items.length - 1;
                    final child = _buildCard(items[i], isTop: isTop, cardWidth: baseWidth, cardHeight: baseHeight, translate: translate);
                    if (isTop) {
                      return RawGestureDetector(
                        gestures: <Type, GestureRecognizerFactory>{
                          HorizontalDragGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
                            () => HorizontalDragGestureRecognizer(),
                            (HorizontalDragGestureRecognizer instance) {
                              instance.onStart = _onHorizontalDragStart;
                              instance.onUpdate = _onHorizontalDragUpdate;
                              instance.onEnd = _onHorizontalDragEnd;
                            },
                          ),
                        },
                        behavior: HitTestBehavior.translucent,
                        child: Transform.translate(
                          offset: Offset(_offset.dx, 0),
                          child: Transform.rotate(
                            // _rotation already contains the clamped rotation in radians
                            angle: _rotation,
                            child: child,
                          ),
                        ),
                      );
                    }
                    return child;
                  })
                ],
              // no overlay labels (EVET/HAYIR) — removed for cleaner UX
            ],
          ),
        ),
        // No controls or progress indicator — show only the card stack
      ],
    );
  }
}
