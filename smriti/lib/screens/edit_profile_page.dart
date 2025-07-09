import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import '../theme.dart';

class EditProfilePage extends StatefulWidget {
  final SubUserProfile profile;
  const EditProfilePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1 fields
  late final TextEditingController _nameController;
  late final TextEditingController _initialsController;
  late final TextEditingController _relationController;
  late final TextEditingController _languageController;
  String? _profileImageUrl;

  // Step 2 fields
  late final TextEditingController _bioController;
  DateTime? _birthDate;
  late final TextEditingController _birthPlaceController;
  late List<String> _tags;
  final _tagController = TextEditingController();

  // Step 3 fields
  bool _archived = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _initialsController = TextEditingController(text: widget.profile.initials);
    _relationController = TextEditingController(text: widget.profile.relation);
    _languageController = TextEditingController(text: widget.profile.languagePreference);
    _profileImageUrl = widget.profile.profileImageUrl;
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _birthDate = widget.profile.birthDate;
    _birthPlaceController = TextEditingController(text: widget.profile.birthPlace ?? '');
    _tags = List<String>.from(widget.profile.tags ?? []);
    _archived = widget.profile.archived;
  }

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
    final updatedProfile = SubUserProfile(
      id: widget.profile.id, // id is not editable
      name: _nameController.text.trim(),
      initials: _initialsController.text.trim(),
      relation: _relationController.text.trim(),
      profileImageUrl: _profileImageUrl,
      languagePreference: _languageController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      birthDate: _birthDate,
      birthPlace: _birthPlaceController.text.trim().isEmpty ? null : _birthPlaceController.text.trim(),
      tags: _tags.isEmpty ? null : List<String>.from(_tags),
      createdAt: widget.profile.createdAt,
      lastInteractionAt: DateTime.now(),
      archived: _archived,
    );
    await SubUserProfileStorage().updateProfile(updatedProfile);
    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTextStyles.headline),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                title: Text('Basic Info', style: AppTextStyles.headline.copyWith(fontSize: 20)),
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
                          TextFormField(
                            controller: _relationController,
                            decoration: InputDecoration(
                              labelText: 'Relation (e.g. Grandmother)',
                              labelStyle: AppTextStyles.body,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: AppTextStyles.body,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a relation' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _languageController,
                            decoration: InputDecoration(
                              labelText: 'Language Preference (e.g. en-US)',
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
                                _birthDate == null ? 'Birth Date: Not set' : 'Birth Date: 	${_birthDate!.toLocal().toString().split(' ')[0]}',
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
      ),
    );
  }
} 