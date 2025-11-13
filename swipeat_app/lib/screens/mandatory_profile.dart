import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../config.dart';
import '../main_screen.dart';

class MandatoryProfileScreen extends StatefulWidget {
  final String idToken; // token we will send to backend
  final String? displayName;
  const MandatoryProfileScreen({required this.idToken, this.displayName, super.key});

  @override
  State<MandatoryProfileScreen> createState() => _MandatoryProfileScreenState();
}

class _MandatoryProfileScreenState extends State<MandatoryProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  String _gender = 'male';
  final String _interestedIn = 'female';
  String _dietGoal = 'Kilo Vermek';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      _nameCtrl.text = widget.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
  final age = int.tryParse(_ageCtrl.text.trim());
  final height = double.tryParse(_heightCtrl.text.trim());
  final weight = double.tryParse(_weightCtrl.text.trim());

  // Build interests with gender metadata so backend can store them without schema change
  final interests = ['gender:$_gender', 'interested:$_interestedIn'];

    final body = jsonEncode({
      'name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'diet_goal': _dietGoal,
      'bio': '',
      'photos': [],
      'interests': interests,
    });

    try {
      final uri = Uri.parse('$backendBaseUrl/api/profiles');
      final resp = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.idToken}',
      }, body: body);

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        // Refresh local profile via provider so app knows profile exists and won't re-prompt
        if (mounted) {
          try {
            // Refresh provider with the token we already have
            Provider.of<UserProvider>(context, listen: false).loadProfile(widget.idToken);
          } catch (_) {}
        }
        // navigate to main app shell
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        final msg = 'Failed to save profile: ${resp.statusCode} ${resp.body}';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete profile')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: Column(children: [
              // Turkish labels and additional fields: height and weight, diet goal
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'İsim'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,),
              SizedBox(height: 12.h),
              Row(children: [
                Expanded(child: TextFormField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Boy (cm)'), validator: (v) { if (v == null || v.trim().isEmpty) return 'Gerekli'; if (double.tryParse(v.trim()) == null) return 'Sayı girin'; return null; })),
                SizedBox(width: 8.w),
                Expanded(child: TextFormField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilo (kg)'), validator: (v) { if (v == null || v.trim().isEmpty) return 'Gerekli'; if (double.tryParse(v.trim()) == null) return 'Sayı girin'; return null; })),
              ]),
              SizedBox(height: 12.h),
              TextFormField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yaş'), validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Gerekli';
                if (int.tryParse(v.trim()) == null) return 'Sayı girin';
                return null;
              }),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(initialValue: _gender, items: const [DropdownMenuItem(value: 'male', child: Text('Erkek')), DropdownMenuItem(value: 'female', child: Text('Kadın')), DropdownMenuItem(value: 'nonbinary', child: Text('Diğer'))], onChanged: (v) { if (v != null) setState(() => _gender = v); }, decoration: const InputDecoration(labelText: 'Cinsiyet'),),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(initialValue: _dietGoal, items: const [DropdownMenuItem(value: 'Kilo Vermek', child: Text('Kilo Vermek')), DropdownMenuItem(value: 'Kilo Korumak', child: Text('Kilo Korumak')), DropdownMenuItem(value: 'Kas Kazanmak', child: Text('Kas Kazanmak'))], onChanged: (v) { if (v != null) setState(() => _dietGoal = v); }, decoration: const InputDecoration(labelText: 'Diyet Hedefi'),),
              SizedBox(height: 18.h),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'))),
            ]),
          ),
        ),
      ),
    );
  }
}
