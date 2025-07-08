import 'package:flutter/material.dart';
import '../theme.dart';

class ProfileSelectionPage extends StatelessWidget {
  final List<Map<String, String>> profiles = const [
    {'name': 'Sudha', 'initials': 'S'},
    {'name': 'Krishna', 'initials': 'K'},
    {'name': 'Ravi', 'initials': 'R'},
    {'name': 'Meera', 'initials': 'M'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, Krishna 👋',
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  itemCount: profiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return Card(
                      color: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.border.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              child: Text(
                                profile['initials']!,
                                style: AppTextStyles.avatarInitials,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              profile['name']!,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
