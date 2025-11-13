import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/profile.dart';

typedef OnSwipe = void Function(Profile profile, bool liked);

class SwipeStack extends StatefulWidget {
  final List<Profile> items;
  final OnSwipe onSwipe;
  final int maxVisible;

  const SwipeStack({required this.items, required this.onSwipe, this.maxVisible = 3, super.key});

  @override
  State<SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<SwipeStack> with SingleTickerProviderStateMixin {
  late List<Profile> items;
  final List<Map<String, dynamic>> history = [];

  // top card anim state
  Offset _offset = Offset.zero;
  double _rotation = 0.0;
  // drag flag not needed yet

  @override
  void initState() {
    super.initState();
    items = List.of(widget.items);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _offset += d.delta;
      _rotation = _offset.dx / 300;
    });
  }

  void _onPanEnd(DragEndDetails e) {
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.25;
    if (_offset.dx > threshold) {
      _doSwipe(true);
    } else if (_offset.dx < -threshold) {
      _doSwipe(false);
    } else {
      // return to center
      setState(() {
        _offset = Offset.zero;
        _rotation = 0.0;
      });
    }
  }

  void _doSwipe(bool liked) {
    if (items.isEmpty) return;
    final top = items.removeLast();
    history.add({'profile': top, 'liked': liked});
    widget.onSwipe(top, liked);
    // reset
    setState(() {
      _offset = Offset.zero;
      _rotation = 0.0;
    });
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
                      return GestureDetector(
                        onPanStart: (_) {},
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Transform.translate(
                          offset: _offset,
                          child: Transform.rotate(
                            angle: _rotation * 0.4,
                            child: child,
                          ),
                        ),
                      );
                    }
                    return child;
                  })
                ],
              // overlay labels
              if (_offset.dx.abs() > 20)
                Positioned(
                  top: 40,
                  left: _offset.dx > 0 ? 40 : null,
                  right: _offset.dx < 0 ? 40 : null,
                  child: Opacity(
                    opacity: math.min(_offset.dx.abs() / 150, 1.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
                      decoration: BoxDecoration(
                        color: _offset.dx > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(_offset.dx > 0 ? 'EVET' : 'HAYIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20.sp)),
                    ),
                  ),
                ),
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
