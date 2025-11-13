import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String title;
  final int kcal;
  const RecipeDetailScreen({required this.title, required this.kcal, super.key});

  @override
  Widget build(BuildContext context) {
    final ingredients = ['2 yumurta', '50g peynir', '1 dilim tam buğday ekmek', 'Domates'];
    final steps = ['Yumurta ve peyniri çırpın', 'Tavada pişirin', 'Ekmek ile servis edin'];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: EdgeInsets.all(12.w),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              ClipRRect(borderRadius: BorderRadius.circular(12.r), child: Container(height: 200.h, color: Colors.grey.shade200)),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('$kcal kcal', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline))],
              ),
              SizedBox(height: 8.h),
              Text('Malzemeler', style: Theme.of(context).textTheme.titleMedium),
              ...ingredients.map((i) => ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(i))),
              SizedBox(height: 8.h),
              Text('Hazırlanışı', style: Theme.of(context).textTheme.titleMedium),
              ...steps.map((s) => Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: Text('• $s'))),
            ],
          ),
        ),
      ),
    );
  }
}
