import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import '../theme.dart';

class AddProfilePage extends StatefulWidget {
  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1 fields
  final _nameController = TextEditingController();
  final _initialsController = TextEditingController();
  final _relationController = TextEditingController();
  final _languageController = TextEditingController();
  String? _profileImageUrl;

  // Step 2 fields
  final _bioController = TextEditingController();
  DateTime? _birthDate;
  final _birthPlaceController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  // Step 3 fields
  bool _archived = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _initialsController.dispose();
    _relationController.dispose();
    _languageController.dispose();
    _bioController.dispose();
    _birthPlaceController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _updateInitials(String name) {
    final parts = name.trim().split(' ');
    String initials = '';
    if (parts.length == 1 && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
    } else if (parts.length > 1) {
      initials = parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    }
    _initialsController.text = initials;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final profile = SubUserProfile(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      initials: _initialsController.text.trim(),
      relation: _relationController.text.trim(),
      profileImageUrl: _profileImageUrl,
      languagePreference: _languageController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      birthDate: _birthDate,
      birthPlace: _birthPlaceController.text.trim().isEmpty ? null : _birthPlaceController.text.trim(),
      tags: _tags.isEmpty ? null : List<String>.from(_tags),
      createdAt: DateTime.now(),
      lastInteractionAt: null,
      archived: _archived,
    );
    await SubUserProfileStorage().addProfile(profile);
    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Profile')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _formKey.currentState!.validate()) {
            setState(() => _currentStep++);
          } else if (_currentStep == 1) {
            setState(() => _currentStep++);
          } else if (_currentStep == 2) {
            _saveProfile();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(_currentStep == 2 ? 'Save' : 'Next'),
              ),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          );
        },
        steps: [
          Step(
            title: Text('Basic Info'),
            isActive: _currentStep >= 0,
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Full Name'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                    onChanged: _updateInitials,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _initialsController,
                    decoration: InputDecoration(labelText: 'Initials'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter initials' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _relationController,
                    decoration: InputDecoration(labelText: 'Relation (e.g. Grandmother)'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a relation' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _languageController,
                    decoration: InputDecoration(labelText: 'Language Preference (e.g. en-US)'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a language' : null,
                  ),
                  const SizedBox(height: 16),
                  // Profile image upload/selection can be added here
                ],
              ),
            ),
          ),
          Step(
            title: Text('Personal Details'),
            isActive: _currentStep >= 1,
            content: Column(
              children: [
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(labelText: 'Bio (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(_birthDate == null ? 'Birth Date: Not set' : 'Birth Date: ${_birthDate!.toLocal().toString().split(' ')[0]}'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1970),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _birthDate = picked);
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthPlaceController,
                  decoration: InputDecoration(labelText: 'Birth Place (optional)'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in _tags)
                      Chip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _tagController,
                        decoration: InputDecoration(hintText: 'Add tag'),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setState(() {
                              _tags.add(value.trim());
                              _tagController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: Text('Review & Save'),
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text('Name'),
                  subtitle: Text(_nameController.text),
                ),
                ListTile(
                  title: Text('Initials'),
                  subtitle: Text(_initialsController.text),
                ),
                ListTile(
                  title: Text('Relation'),
                  subtitle: Text(_relationController.text),
                ),
                ListTile(
                  title: Text('Language'),
                  subtitle: Text(_languageController.text),
                ),
                if (_bioController.text.isNotEmpty)
                  ListTile(
                    title: Text('Bio'),
                    subtitle: Text(_bioController.text),
                  ),
                if (_birthDate != null)
                  ListTile(
                    title: Text('Birth Date'),
                    subtitle: Text(_birthDate!.toLocal().toString().split(' ')[0]),
                  ),
                if (_birthPlaceController.text.isNotEmpty)
                  ListTile(
                    title: Text('Birth Place'),
                    subtitle: Text(_birthPlaceController.text),
                  ),
                if (_tags.isNotEmpty)
                  ListTile(
                    title: Text('Tags'),
                    subtitle: Text(_tags.join(', ')),
                  ),
                SwitchListTile(
                  title: Text('Archive this profile'),
                  value: _archived,
                  onChanged: (val) => setState(() => _archived = val),
                ),
                if (_isSaving)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 