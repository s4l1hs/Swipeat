import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'loading_plan.dart';

class TargetSettingScreen extends StatefulWidget {
  const TargetSettingScreen({super.key});

  @override
  State<TargetSettingScreen> createState() => _TargetSettingScreenState();
}

class _TargetSettingScreenState extends State<TargetSettingScreen> {
  String _goal = 'Kilo Vermek';
  final TextEditingController _calController = TextEditingController();

  Future<void> _openTdeeModal() async {
    final result = await showDialog<int?>(context: context, builder: (_) => const _TdeeDialog());
    if (result != null) {
      _calController.text = result.toString();
    }
  }

  void _createPlan() {
    final calories = int.tryParse(_calController.text) ?? 2000;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoadingPlanScreen(targetCalories: calories, goal: _goal)));
  }

  @override
  void dispose() {
    _calController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hedefini Belirle')),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),
            Text('Harika! Şimdi hedefini seç.', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16.h),
            ToggleButtons(
              isSelected: [ _goal == 'Kilo Vermek', _goal == 'Kilo Korumak', _goal == 'Kas Kazanmak' ],
              onPressed: (i) {
                setState(() {
                  _goal = i == 0 ? 'Kilo Vermek' : i == 1 ? 'Kilo Korumak' : 'Kas Kazanmak';
                });
              },
              borderRadius: BorderRadius.circular(12.r),
              selectedColor: Colors.white,
              fillColor: Theme.of(context).colorScheme.primary,
              children: [ const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), child: Text('Kilo Vermek')), const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), child: Text('Kilo Korumak')), const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), child: Text('Kas Kazanmak')) ],
            ),
            SizedBox(height: 18.h),
            Text('Günlük Kalori İhtiyacın', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _calController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kalori (kcal)')),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(onPressed: _openTdeeModal, child: const Text('Benim İçin Hesapla'))
              ],
            ),
            const Spacer(),
            ElevatedButton(onPressed: _createPlan, child: const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text('Planımı Oluştur!'))),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}

class _TdeeDialog extends StatefulWidget {
  const _TdeeDialog();
  @override
  State<_TdeeDialog> createState() => _TdeeDialogState();
}

class _TdeeDialogState extends State<_TdeeDialog> {
  final _w = TextEditingController();
  final _h = TextEditingController();
  final _a = TextEditingController();
  double _activity = 1.2;

  int _calc() {
    // Simple Mifflin-St Jeor estimate (gender-neutral, uses 1500 baseline)
    final weight = double.tryParse(_w.text) ?? 70.0;
    final height = double.tryParse(_h.text) ?? 170.0;
    final age = int.tryParse(_a.text) ?? 30;
    // approximate BMR
    final bmr = 10 * weight + 6.25 * height - 5 * age + 5; // male baseline
    final tdee = (bmr * _activity).round();
    return tdee;
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kalori Hesaplayıcı'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _w, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilo (kg)')),
            TextField(controller: _h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Boy (cm)')),
            TextField(controller: _a, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yaş')),
            SizedBox(height: 8.h),
            DropdownButton<double>(value: _activity, items: const [ DropdownMenuItem(value: 1.2, child: Text('Hareketsiz')), DropdownMenuItem(value: 1.375, child: Text('Hafif Aktif')), DropdownMenuItem(value: 1.55, child: Text('Orta Aktif')), DropdownMenuItem(value: 1.725, child: Text('Çok Aktif')) ], onChanged: (v) => setState(() => _activity = v ?? 1.2)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('İptal')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(_calc()), child: const Text('Hesapla')),
      ],
    );
  }
}
