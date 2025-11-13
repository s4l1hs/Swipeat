import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/profile.dart';
import '../widgets/swipe_stack.dart';
import 'target_setting.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late List<Profile> cards;

  @override
  void initState() {
    super.initState();
    cards = List.generate(8, (i) {
      return Profile(
        id: 'food$i',
        name: ['Brokoli', 'Somonlu Salata', 'Tatlı Patates', 'Avokado Tost', 'Yoğurt & Meyve', 'Fırında Tavuk', 'Mercimek Çorbası', 'Smoothie'][i % 8],
        age: null,
        bio: 'Lezzetli ve sağlıklı örnek tarif',
        photos: [],
        interests: [],
      );
    }).reversed.toList();
  }

  void _onSwipe(Profile p, bool liked) {
    setState(() => cards.remove(p));
    if (cards.isEmpty) {
      // Move to target setting flow
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TargetSettingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 12.h),
              Text('Sevdiğin Yiyecekleri Söyle', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: 8.h),
              Text('Sana özel diyet planını hazırlayalım', style: Theme.of(context).textTheme.bodyMedium),
              SizedBox(height: 18.h),
              Expanded(
                child: Center(
                  child: cards.isEmpty
                      ? const Text('Hazırlanıyor...')
                      : SwipeStack(items: cards, onSwipe: (p, liked) => _onSwipe(p, liked)),
                ),
              ),
              SizedBox(height: 12.h),
              Text('Sevmiyorsan sola, seviyorsan sağa çek', style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    );
  }
}
