import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';

class TimelinePage extends StatefulWidget {
  final SubUserProfile profile;
  const TimelinePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final birthYear = widget.profile.birthDate?.year?.toString() ?? 'Year?';
    final birthPlace = widget.profile.birthPlace ?? 'Place?';
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: AppTextStyles.headline.copyWith(fontSize: 18),
                unselectedLabelStyle: AppTextStyles.body,
                tabs: const [
                  Tab(text: 'Timeline'),
                  Tab(text: 'Graph'),
                  Tab(text: 'Mosaic'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Timeline Tab
                    ListView(
                      children: [
                        Card(
                          color: AppColors.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primary.withOpacity(0.08),
                                  child: Text(
                                    birthYear,
                                    style: AppTextStyles.headline.copyWith(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Born in', style: AppTextStyles.label),
                                      Text(
                                        birthPlace,
                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // TODO: Add more timeline entries as stories are added
                      ],
                    ),
                    // Graph Tab
                    Center(
                      child: Text('Graph View (coming soon)', style: AppTextStyles.body),
                    ),
                    // Mosaic Tab
                    Center(
                      child: Text('Mosaic View (stories by category, coming soon)', style: AppTextStyles.body),
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
