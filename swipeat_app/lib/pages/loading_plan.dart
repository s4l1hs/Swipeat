import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'plan_overview.dart';

class LoadingPlanScreen extends StatefulWidget {
  final int targetCalories;
  final String goal;
  const LoadingPlanScreen({required this.targetCalories, required this.goal, super.key});

  @override
  State<LoadingPlanScreen> createState() => _LoadingPlanScreenState();
}

class _LoadingPlanScreenState extends State<LoadingPlanScreen> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // fake work then navigate
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlanOverviewScreen(targetCalories: widget.targetCalories)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              SizedBox(
                width: 160.w,
                height: 160.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary), strokeWidth: 8.w),
                    const Icon(Icons.local_dining, size: 56),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Text('Sihir yapılıyor...', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 8.h),
              Padding(padding: EdgeInsets.symmetric(horizontal: 24.w), child: const Text("Sadece 'Evet' dediklerini kullanarak planın optimize ediliyor…", textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
