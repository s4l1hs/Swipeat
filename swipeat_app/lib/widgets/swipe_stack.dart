import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/profile.dart';

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

  void _doSwipe(bool liked) {
    if (items.isEmpty) return;
    final top = items.last;
    _performSwipeAnim(top, liked);
  }

  void _undo() {
    if (history.isEmpty) return;
    final last = history.removeLast();
    items.add(last['profile'] as Profile);
    setState(() {});
  }

  Widget _buildCard(Profile p, {required bool isTop, required double scale, required double translate}) {
    return Transform.translate(
      offset: Offset(0, translate),
      child: Transform.scale(
        scale: scale,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          elevation: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: p.photos.isNotEmpty
                      ? Image.network(p.photos.first, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox())
                      : Container(color: Colors.grey.shade200),
                ),
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.name}, ${p.age ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 6.h),
                      Text(p.bio ?? '', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
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
                    final scale = 1.0 - 0.04 * depth;
                    final translate = 12.0 * depth;
                    final isTop = i == items.length - 1;
                    final child = _buildCard(items[i], isTop: isTop, scale: scale, translate: translate);
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
        SizedBox(height: 18.h),
        // progress indicator
        LinearProgressIndicator(
          value: widget.items.isEmpty ? 1.0 : (widget.items.length - items.length) / (widget.items.length + history.length == 0 ? 1 : widget.items.length + history.length),
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
          minHeight: 8.h,
        ),
        SizedBox(height: 18.h),
        // controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _undo,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
            ),
            SizedBox(width: 24.w),
            FloatingActionButton(
              heroTag: 'no',
              onPressed: () => _doSwipe(false),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.close),
            ),
            SizedBox(width: 24.w),
            FloatingActionButton(
              heroTag: 'yes',
              onPressed: () => _doSwipe(true),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.favorite),
            ),
          ],
        )
      ],
    );
  }
}
