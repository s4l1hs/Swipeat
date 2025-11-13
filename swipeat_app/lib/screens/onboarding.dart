import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// id generation doesn't require external package here
import '../models/profile.dart';
import 'swipe_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _photosCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    _photosCtrl.dispose();
    _interestsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
  final id = DateTime.now().microsecondsSinceEpoch.toString();
    final profile = Profile(
      id: id,
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()),
      bio: _bioCtrl.text.trim(),
      photos: _photosCtrl.text.trim().isEmpty ? [] : _photosCtrl.text.trim().split(',').map((s) => s.trim()).toList(),
      interests: _interestsCtrl.text.trim().isEmpty ? [] : _interestsCtrl.text.trim().split(',').map((s) => s.trim()).toList(),
    );

    // For now navigate to swipe screen and pass this profile as "me".
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SwipeScreen(me: profile)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your profile')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Short bio'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _photosCtrl,
                    decoration: const InputDecoration(labelText: 'Photos (comma-separated URLs)'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _interestsCtrl,
                    decoration: const InputDecoration(labelText: 'Interests (comma-separated)'),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Start swiping', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
