import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'recipe_detail.dart';

class PlanOverviewScreen extends StatefulWidget {
  final int targetCalories;
  const PlanOverviewScreen({required this.targetCalories, super.key});

  @override
  State<PlanOverviewScreen> createState() => _PlanOverviewScreenState();
}

class _PlanOverviewScreenState extends State<PlanOverviewScreen> {
  int selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final days = ['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'];
    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık Planım')),
      body: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          children: [
            SizedBox(
              height: 64.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                itemBuilder: (ctx, i) {
                  final sel = i == selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDay = i),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8.w),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(color: sel ? Theme.of(context).colorScheme.primary : Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.grey.shade200)),
                      child: Center(child: Text(days[i], style: TextStyle(color: sel ? Colors.white : Colors.black))),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView(
                children: [
                  _mealCard(context, 'Kahvaltı', 'Peynirli Omlet', 420),
                  _mealCard(context, 'Öğle', 'Somonlu Salata', 610),
                  _mealCard(context, 'Akşam', 'Fırında Tavuk & Sebze', 740),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _mealCard(BuildContext ctx, String slot, String title, int kcal) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: ListTile(
        leading: SizedBox(width: 72.w, child: ClipRRect(borderRadius: BorderRadius.circular(8.r), child: Container(color: Colors.grey.shade200))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$kcal kcal'),
        trailing: IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(title: title, kcal: kcal)))),
      ),
    );
  }
}
