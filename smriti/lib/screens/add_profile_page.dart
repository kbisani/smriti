import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/profile.dart';
import '../storage/hive_profile_storage.dart';

class AddProfilePage extends StatefulWidget {
  @override
  _AddProfilePageState createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // For now, avatarPath is optional and not implemented

  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final profile = Profile(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      avatarPath: '',
      createdAt: DateTime.now(),
    );
    await HiveProfileStorage().addProfile(profile);
    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 32),
              _isSaving
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: Icon(Icons.check),
                      label: Text('Add Profile'),
                      onPressed: _saveProfile,
                    ),
            ],
          ),
        ),
      ),
    );
  }
} 