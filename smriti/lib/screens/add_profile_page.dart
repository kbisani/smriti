import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import '../theme.dart';
import '../storage/qdrant_profile_service.dart';
import '../models/main_user.dart';
import '../storage/main_user_storage.dart';
import 'profile_selection.dart';
import '../models/profile_memory.dart';

class AddProfilePage extends StatefulWidget {
  final bool isMainUser;
  final SubUserProfile? existingProfile; // For editing existing profiles
  const AddProfilePage({
    Key? key, 
    this.isMainUser = false, 
    this.existingProfile,
  }) : super(key: key);
  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _formKey = GlobalKey<FormState>();
  late final QdrantProfileService _profileService;

  // Form fields
  final _nameController = TextEditingController();
  final _initialsController = TextEditingController();
  final _relationController = TextEditingController();
  final _languageController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _birthDate;
  final _birthPlaceController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  String? _profileImageUrl;
  bool _archived = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileService = QdrantProfileService();
    
    // If editing existing profile, populate fields
    if (widget.existingProfile != null) {
      final profile = widget.existingProfile!;
      _nameController.text = profile.name;
      _initialsController.text = profile.initials;
      _relationController.text = profile.relation;
      _languageController.text = profile.languagePreference;
      _bioController.text = profile.bio ?? '';
      _birthDate = profile.birthDate;
      _birthPlaceController.text = profile.birthPlace ?? '';
      _tags.addAll(profile.tags ?? []);
      _profileImageUrl = profile.profileImageUrl;
      _archived = profile.archived;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      // Validate basic info
      if (_nameController.text.trim().isEmpty || 
          _initialsController.text.trim().isEmpty ||
          _languageController.text.trim().isEmpty ||
          (!widget.isMainUser && _relationController.text.trim().isEmpty)) {
        return false;
      }
    } else if (_currentPage == 1) {
      // Validate birth date and place (now required)
      if (_birthDate == null || _birthPlaceController.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _saveProfile();
      }
    } else {
      _showValidationError();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showValidationError() {
    String message = '';
    if (_currentPage == 0) {
      message = 'Please fill in all required fields';
    } else if (_currentPage == 1) {
      message = 'Birth date and birth place are required';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_validateCurrentPage()) {
      _showValidationError();
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final isEditing = widget.existingProfile != null;
      final id = isEditing ? widget.existingProfile!.id : const Uuid().v4();
      
      final profile = SubUserProfile(
        id: id,
        name: _nameController.text.trim(),
        initials: _initialsController.text.trim(),
        relation: widget.isMainUser ? 'Your Journal' : _relationController.text.trim(),
        profileImageUrl: _profileImageUrl,
        languagePreference: _languageController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        birthDate: _birthDate,
        birthPlace: _birthPlaceController.text.trim(),
        tags: _tags.isEmpty ? null : List<String>.from(_tags),
        createdAt: isEditing ? widget.existingProfile!.createdAt : now,
        lastInteractionAt: widget.existingProfile?.lastInteractionAt,
        archived: _archived,
      );
      
      // Initialize Qdrant service
      await _profileService.initialize();
      
      if (isEditing) {
        // Update existing profile
        await SubUserProfileStorage().updateProfile(profile);
        await _profileService.storeProfile(profile); // Update in Qdrant too
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Create new profile
        await SubUserProfileStorage().addProfile(profile);
        await _profileService.storeProfile(profile);
        
        // Create initial memory and store in Qdrant for new profiles
        final memory = ProfileMemory(name: profile.name);
        print('DEBUG ProfileMemory: Creating initial memory for ${profile.name}: ${memory.toJsonString()}');
        await _profileService.storeProfileMemory(profile.id, memory);
        print('DEBUG ProfileMemory: Initial memory stored for profile ${profile.id}');
        
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
      }
    } catch (e, st) {
      print('Error ${widget.existingProfile != null ? 'updating' : 'creating'} profile: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${widget.existingProfile != null ? 'update' : 'create'} profile. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingProfile != null
              ? 'Edit Profile'
              : (widget.isMainUser ? 'Welcome to Smriti' : 'Add Profile'), 
          style: AppTextStyles.headline.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _currentPage 
                              ? AppColors.primary 
                              : AppColors.border.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildBasicInfoPage(),
                  _buildPersonalDetailsPage(),
                  _buildReviewPage(),
                ],
              ),
            ),
            
            // Bottom navigation
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Back', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                      ),
                      child: _isSaving 
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _currentPage == 2 
                                  ? (widget.existingProfile != null ? 'Update Profile' : 'Create Profile') 
                                  : 'Next',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isMainUser) ...[
            Text(
              'Let\'s create your profile',
              style: AppTextStyles.headline.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This will be your personal journal where you can record and preserve your memories.',
              style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Text(
              'Basic Information',
              style: AppTextStyles.headline.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about this person whose memories you\'d like to preserve.',
              style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 32),
          ],
          
          // Profile Avatar Section
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                  ),
                  child: _profileImageUrl != null
                      ? ClipOval(child: Image.network(_profileImageUrl!, fit: BoxFit.cover))
                      : Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement image picker
                  },
                  icon: Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
                  label: Text(
                    'Add Photo',
                    style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Form fields
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            onChanged: _updateInitials,
            required: true,
          ),
          const SizedBox(height: 20),
          
          _buildTextField(
            controller: _initialsController,
            label: 'Initials',
            icon: Icons.label_outline,
            required: true,
            maxLength: 3,
          ),
          const SizedBox(height: 20),
          
          if (!widget.isMainUser) ...[
            _buildTextField(
              controller: _relationController,
              label: 'Relation to You',
              icon: Icons.people_outline,
              hint: 'e.g. Mother, Father, Friend',
              required: true,
            ),
            const SizedBox(height: 20),
          ],
          
          _buildTextField(
            controller: _languageController,
            label: 'Preferred Language',
            icon: Icons.language,
            hint: 'e.g. English, Hindi, Spanish',
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: AppTextStyles.headline.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'These details help us personalize the memory experience and provide better context.',
            style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          
          // Birth Date
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime(1970),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: AppColors.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Birth Date *',
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _birthDate == null 
                                ? 'Select birth date'
                                : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                            style: AppTextStyles.body.copyWith(
                              color: _birthDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          _buildTextField(
            controller: _birthPlaceController,
            label: 'Birth Place',
            icon: Icons.location_on_outlined,
            hint: 'City, Country',
            required: true,
          ),
          
          const SizedBox(height: 20),
          
          _buildTextField(
            controller: _bioController,
            label: 'Bio',
            icon: Icons.description_outlined,
            hint: 'Tell us a bit about ${widget.isMainUser ? 'yourself' : 'this person'}...',
            maxLines: 3,
          ),
          
          const SizedBox(height: 24),
          
          // Tags section
          Text(
            'Tags (Optional)',
            style: AppTextStyles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add keywords that describe interests, hobbies, or characteristics',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          // Tags input and display
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && !_tags.contains(value.trim())) {
                      setState(() {
                        _tags.add(value.trim());
                        _tagController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final value = _tagController.text.trim();
                  if (value.isNotEmpty && !_tags.contains(value)) {
                    setState(() {
                      _tags.add(value);
                      _tagController.clear();
                    });
                  }
                },
                icon: Icon(Icons.add, color: AppColors.primary),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) => Chip(
                label: Text(tag, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                backgroundColor: AppColors.primary.withOpacity(0.1),
                deleteIcon: Icon(Icons.close, size: 16, color: AppColors.primary),
                onDeleted: () => setState(() => _tags.remove(tag)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existingProfile != null ? 'Review & Update' : 'Review & Create',
            style: AppTextStyles.headline.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.existingProfile != null
                ? 'Please review the information before updating the profile.'
                : 'Please review the information before creating the profile.',
            style: AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildReviewItem('Name', _nameController.text, Icons.person_outline),
                _buildDivider(),
                _buildReviewItem('Initials', _initialsController.text, Icons.label_outline),
                if (!widget.isMainUser) ...[
                  _buildDivider(),
                  _buildReviewItem('Relation', _relationController.text, Icons.people_outline),
                ],
                _buildDivider(),
                _buildReviewItem('Language', _languageController.text, Icons.language),
                _buildDivider(),
                _buildReviewItem(
                  'Birth Date', 
                  _birthDate != null ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}' : 'Not set',
                  Icons.cake_outlined,
                ),
                _buildDivider(),
                _buildReviewItem('Birth Place', _birthPlaceController.text, Icons.location_on_outlined),
                if (_bioController.text.isNotEmpty) ...[
                  _buildDivider(),
                  _buildReviewItem('Bio', _bioController.text, Icons.description_outlined, maxLines: 3),
                ],
                if (_tags.isNotEmpty) ...[
                  _buildDivider(),
                  _buildReviewItem('Tags', _tags.join(', '), Icons.tag, maxLines: 2),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (!widget.isMainUser)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: SwitchListTile(
                title: Text(
                  'Archive this profile',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Archived profiles won\'t appear in the main list',
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                ),
                value: _archived,
                onChanged: (val) => setState(() => _archived = val),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: AppTextStyles.label.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: required ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            counterText: '',
          ),
          style: AppTextStyles.body.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    color: value.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppColors.border.withOpacity(0.2),
      indent: 20,
      endIndent: 20,
    );
  }
}
