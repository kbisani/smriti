import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/main_user.dart';
import '../storage/main_user_storage.dart';
import 'profile_selection.dart'; // Added import for ProfileSelectionPage

class MainUserOnboardingPage extends StatefulWidget {
  @override
  _MainUserOnboardingPageState createState() => _MainUserOnboardingPageState();
}

class _MainUserOnboardingPageState extends State<MainUserOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveMainUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = MainUser(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      avatarPath: '',
      createdAt: DateTime.now(),
    );
    await MainUserStorage().saveMainUser(user);
    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProfileSelectionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome!')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 64, height: 64),
              const SizedBox(height: 24),
              Text(
                'Let’s set up your account',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Your Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: Icon(Icons.check),
                      label: Text('Continue'),
                      onPressed: _saveMainUser,
                    ),
            ],
          ),
        ),
      ),
    );
  }
} 