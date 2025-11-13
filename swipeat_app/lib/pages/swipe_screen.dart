import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/profile.dart';

class SwipeScreen extends StatefulWidget {
  final Profile me;
  const SwipeScreen({required this.me, super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeCard extends StatelessWidget {
  final Profile profile;
  const _SwipeCard({required this.profile});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
  return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      elevation: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: photo != null
                    ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Icon(Icons.person, size: 56.sp)))
                    : Center(child: Icon(Icons.person, size: 64.sp)),
              ),
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${profile.name}, ${profile.age ?? ''}', style: theme.textTheme.titleLarge),
                    SizedBox(height: 6.h),
                    Text(profile.bio ?? '', style: theme.textTheme.bodyMedium),
                    SizedBox(height: 6.h),
                    Wrap(spacing: 8.w, children: profile.interests.map((t) => Chip(label: Text(t))).toList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeScreenState extends State<SwipeScreen> {
  // simple local candidate list
  late List<Profile> candidates;

  @override
  void initState() {
    super.initState();
    // Example dummy candidates - in real app load from backend
    candidates = List.generate(6, (i) {
      return Profile(
        id: 'c$i',
        name: 'Person ${i + 1}',
        age: 20 + i,
        bio: 'Loves design, music and long walks.',
        photos: [],
        interests: ['music', 'design'],
      );
    }).reversed.toList(); // reversed so last is on bottom
  }

  void _onSwipe(Profile p, bool liked) {
    setState(() => candidates.remove(p));
    // TODO: send swipe to backend
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${liked ? 'Liked' : 'Skipped'} ${p.name}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: candidates.isEmpty
                      ? const Text('No more profiles')
                      : Stack(
                          clipBehavior: Clip.none,
                          children: candidates.map((p) {
                            final index = candidates.indexOf(p);
                            // offset to create stacked look; avoid using both left+right which can
                            // introduce negative width constraints when offsets grow large.
                            final offset = 10.0 * (candidates.length - index).toDouble();
                            return Transform.translate(
                              offset: Offset(offset, offset),
                              child: Center(
                                child: Draggable<Profile>(
                                  data: p,
                                  onDragEnd: (details) {
                                    final dx = details.offset.dx - (MediaQuery.of(context).size.width / 2);
                                    if (dx > 100) _onSwipe(p, true);
                                    else if (dx < -100) _onSwipe(p, false);
                                  },
                                  feedback: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    height: MediaQuery.of(context).size.height * 0.65,
                                    child: _SwipeCard(profile: p),
                                  ),
                                  childWhenDragging: const SizedBox.shrink(),
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    height: MediaQuery.of(context).size.height * 0.65,
                                    child: _SwipeCard(profile: p),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }
}
