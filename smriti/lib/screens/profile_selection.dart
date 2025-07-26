import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import 'add_profile_page.dart';
import 'profile_home_page.dart';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({Key? key}) : super(key: key);

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  List<SubUserProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    final profiles = await SubUserProfileStorage().getProfiles();
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _addProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddProfilePage()),
    );
    if (result == true) {
      _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Image.asset('assets/logo.png', width: 32, height: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Smriti',
                    style: AppTextStyles.headline.copyWith(fontSize: 28),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your journal & family memory bank',
                style: AppTextStyles.label.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProfileSections(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSections() {
    final mainUser = _profiles.where((p) => p.relation.toLowerCase() == 'your journal').toList();
    final familyMembers = _profiles.where((p) => p.relation.toLowerCase() != 'your journal').toList();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mainUser.isNotEmpty) ...[
            Text(
              'You',
              style: AppTextStyles.body.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileCard(mainUser.first, isMainUser: true),
            const SizedBox(height: 32),
          ],
          Text(
            'Family Members',
            style: AppTextStyles.body.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: familyMembers.length + 1,
            itemBuilder: (context, index) {
              if (index == familyMembers.length) {
                return _buildAddProfileCard();
              }
              final profile = familyMembers[index];
              return _buildProfileCard(profile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(SubUserProfile profile, {bool isMainUser = false}) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileHomePage(profile: profile),
          ),
        );
        if (result == true) {
          _loadProfiles();
        }
      },
      child: Container(
        width: isMainUser ? double.infinity : null,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMainUser 
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border.withOpacity(0.1)
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMainUser ? 24 : 12),
          child: isMainUser 
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: Text(
                        profile.initials.isNotEmpty ? profile.initials : '',
                        style: AppTextStyles.avatarInitials.copyWith(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            profile.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your personal journal',
                            style: AppTextStyles.label.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        profile.initials.isNotEmpty ? profile.initials : '',
                        style: AppTextStyles.avatarInitials.copyWith(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Text(
                        profile.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.relation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          profile.relation,
                          style: AppTextStyles.label.copyWith(fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAddProfileCard() {
    return GestureDetector(
      onTap: _addProfile,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 32,
              color: AppColors.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Family\nMember',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}