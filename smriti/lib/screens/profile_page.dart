import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import 'add_profile_page.dart';

class ProfilePage extends StatelessWidget {
  final SubUserProfile profile;
  
  const ProfilePage({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTextStyles.headline.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddProfilePage(
                    existingProfile: profile,
                    isMainUser: profile.relation == 'Your Journal',
                  ),
                ),
              );
              
              if (result == true && context.mounted) {
                // Profile was updated, pop back to refresh parent
                Navigator.of(context).pop(true);
              }
            },
            icon: Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 3),
                      ),
                      child: profile.profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                profile.profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.primary.withOpacity(0.6),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.primary.withOpacity(0.6),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        profile.relation,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Profile Details
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _buildDetailItem(
                      'Initials',
                      profile.initials,
                      Icons.label_outline,
                    ),
                    _buildDivider(),
                    _buildDetailItem(
                      'Language',
                      profile.languagePreference,
                      Icons.language,
                    ),
                    if (profile.birthDate != null) ...[
                      _buildDivider(),
                      _buildDetailItem(
                        'Birth Date',
                        '${profile.birthDate!.day}/${profile.birthDate!.month}/${profile.birthDate!.year}',
                        Icons.cake_outlined,
                      ),
                    ],
                    if (profile.birthPlace != null && profile.birthPlace!.isNotEmpty) ...[
                      _buildDivider(),
                      _buildDetailItem(
                        'Birth Place',
                        profile.birthPlace!,
                        Icons.location_on_outlined,
                      ),
                    ],
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      _buildDivider(),
                      _buildDetailItem(
                        'Bio',
                        profile.bio!,
                        Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                    if (profile.tags != null && profile.tags!.isNotEmpty) ...[
                      _buildDivider(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.tag, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tags',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: profile.tags!.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        tag,
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Profile Statistics
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Statistics',
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Created',
                            '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}',
                            Icons.calendar_today_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Status',
                            profile.archived ? 'Archived' : 'Active',
                            profile.archived ? Icons.archive_outlined : Icons.check_circle_outline,
                          ),
                        ),
                      ],
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

  Widget _buildDetailItem(String label, String value, IconData icon, {int maxLines = 1}) {
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
                  value,
                  style: AppTextStyles.body.copyWith(fontSize: 16),
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
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