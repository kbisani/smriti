import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import '../theme.dart';
import '../storage/archive_utils.dart';
import '../models/main_user.dart';
import '../storage/main_user_storage.dart';
import 'profile_selection.dart';
import '../models/profile_memory.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AddProfilePage extends StatefulWidget {
  final bool isMainUser;
  const AddProfilePage({Key? key, this.isMainUser = false}) : super(key: key);
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
    try {
      final now = DateTime.now();
      final id = widget.isMainUser ? const Uuid().v4() : const Uuid().v4();
      final profile = SubUserProfile(
        id: id,
        name: _nameController.text.trim(),
        initials: _initialsController.text.trim(),
        relation: widget.isMainUser ? 'Your Journal' : _relationController.text.trim(),
        profileImageUrl: _profileImageUrl,
        languagePreference: _languageController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        birthDate: _birthDate,
        birthPlace: _birthPlaceController.text.trim().isEmpty ? null : _birthPlaceController.text.trim(),
        tags: _tags.isEmpty ? null : List<String>.from(_tags),
        createdAt: now,
        lastInteractionAt: null,
        archived: _archived,
      );
      await SubUserProfileStorage().addProfile(profile);
      // Ensure profile archive directory exists before writing memory.json
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/archive/profile_$id');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      // Write initial memory.json with name
      final memory = ProfileMemory(name: profile.name);
      await writeProfileMemory(profile.id, memory);
      if (widget.isMainUser) {
        // Save as MainUser as well
        final mainUser = MainUser(
          id: id,
          name: _nameController.text.trim(),
          avatarPath: _profileImageUrl ?? '',
          createdAt: now,
        );
        await MainUserStorage().saveMainUser(mainUser);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => ProfileSelectionPage()),
            (route) => false,
          );
        }
      } else {
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      print('Error creating profile: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create profile. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isMainUser ? 'Set Up Your Journal' : 'Add Profile', style: AppTextStyles.headline),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isMainUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'This is your personal journal profile. You can add others later.',
                    style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ),
              Expanded(
                child: Stepper(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                          child: Text(_currentStep == 2 ? 'Save' : 'Next'),
                        ),
                        if (_currentStep > 0)
                          TextButton(
                            onPressed: details.onStepCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              textStyle: AppTextStyles.body,
                            ),
                            child: const Text('Back'),
                          ),
                      ],
                    );
                  },
                  steps: [
                    Step(
                      title: Text(widget.isMainUser ? 'About You' : 'Basic Info', style: AppTextStyles.headline.copyWith(fontSize: 20)),
                      isActive: _currentStep >= 0,
                      content: Card(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    labelStyle: AppTextStyles.body,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: AppTextStyles.body,
                                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a name' : null,
                                  onChanged: _updateInitials,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _initialsController,
                                  decoration: InputDecoration(
                                    labelText: 'Initials',
                                    labelStyle: AppTextStyles.body,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: AppTextStyles.body,
                                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter initials' : null,
                                ),
                                const SizedBox(height: 16),
                                if (!widget.isMainUser)
                                  TextFormField(
                                    controller: _relationController,
                                    decoration: InputDecoration(
                                      labelText: 'Relation',
                                      labelStyle: AppTextStyles.body,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    style: AppTextStyles.body,
                                    validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a relation' : null,
                                  ),
                                if (widget.isMainUser)
                                  TextFormField(
                                    controller: TextEditingController(text: 'Your Journal'),
                                    decoration: InputDecoration(
                                      labelText: 'Relation',
                                      labelStyle: AppTextStyles.body,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    style: AppTextStyles.body,
                                    enabled: false,
                                  ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _languageController,
                                  decoration: InputDecoration(
                                    labelText: 'Language',
                                    labelStyle: AppTextStyles.body,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: AppTextStyles.body,
                                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a language' : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Step(
                      title: Text('Personal Details', style: AppTextStyles.headline.copyWith(fontSize: 20)),
                      isActive: _currentStep >= 1,
                      content: Card(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _bioController,
                                decoration: InputDecoration(
                                  labelText: 'Bio (optional)',
                                  labelStyle: AppTextStyles.body,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: AppTextStyles.body,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _birthDate == null ? 'Birth Date: Not set' : 'Birth Date: ${_birthDate!.toLocal().toString().split(' ')[0]}',
                                      style: AppTextStyles.body,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _birthDate ?? DateTime(1970),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) setState(() => _birthDate = picked);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    child: const Text('Pick Date'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _birthPlaceController,
                                decoration: InputDecoration(
                                  labelText: 'Birth Place (optional)',
                                  labelStyle: AppTextStyles.body,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: AppTextStyles.body,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final tag in _tags)
                                    Chip(
                                      label: Text(tag, style: AppTextStyles.label),
                                      backgroundColor: AppColors.primary.withOpacity(0.08),
                                      deleteIcon: Icon(Icons.close, size: 18),
                                      onDeleted: () => setState(() => _tags.remove(tag)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _tagController,
                                      decoration: InputDecoration(
                                        hintText: 'Add tag',
                                        hintStyle: AppTextStyles.label,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      style: AppTextStyles.body,
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
                      ),
                    ),
                    Step(
                      title: Text('Review & Save', style: AppTextStyles.headline.copyWith(fontSize: 20)),
                      isActive: _currentStep >= 2,
                      content: Card(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text('Name', style: AppTextStyles.label),
                                subtitle: Text(_nameController.text, style: AppTextStyles.body),
                              ),
                              ListTile(
                                title: Text('Initials', style: AppTextStyles.label),
                                subtitle: Text(_initialsController.text, style: AppTextStyles.body),
                              ),
                              ListTile(
                                title: Text('Relation', style: AppTextStyles.label),
                                subtitle: Text(_relationController.text, style: AppTextStyles.body),
                              ),
                              ListTile(
                                title: Text('Language', style: AppTextStyles.label),
                                subtitle: Text(_languageController.text, style: AppTextStyles.body),
                              ),
                              if (_bioController.text.isNotEmpty)
                                ListTile(
                                  title: Text('Bio', style: AppTextStyles.label),
                                  subtitle: Text(_bioController.text, style: AppTextStyles.body),
                                ),
                              if (_birthDate != null)
                                ListTile(
                                  title: Text('Birth Date', style: AppTextStyles.label),
                                  subtitle: Text(_birthDate!.toLocal().toString().split(' ')[0], style: AppTextStyles.body),
                                ),
                              if (_birthPlaceController.text.isNotEmpty)
                                ListTile(
                                  title: Text('Birth Place', style: AppTextStyles.label),
                                  subtitle: Text(_birthPlaceController.text, style: AppTextStyles.body),
                                ),
                              if (_tags.isNotEmpty)
                                ListTile(
                                  title: Text('Tags', style: AppTextStyles.label),
                                  subtitle: Text(_tags.join(', '), style: AppTextStyles.body),
                                ),
                              SwitchListTile(
                                title: Text('Archive this profile', style: AppTextStyles.label),
                                value: _archived,
                                onChanged: (val) => setState(() => _archived = val),
                                activeColor: AppColors.primary,
                              ),
                              if (_isSaving)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 