import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import 'record_page.dart';
import 'profile_page.dart';
import '../storage/sub_user_profile_storage.dart';
import '../storage/qdrant_profile_service.dart';
import '../storage/prompt_generation_service.dart';
import '../storage/story_continuation_service.dart';
import 'timeline.dart';
import 'archive.dart';

class ProfileHomePage extends StatefulWidget {
  final SubUserProfile profile;
  const ProfileHomePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<ProfileHomePage> createState() => _ProfileHomePageState();
}

class _ProfileHomePageState extends State<ProfileHomePage> with WidgetsBindingObserver {
  static const Color darkIndigo = Color(0xFF283593);
  int _selectedIndex = 0;
  late final PageController _pageController;
  late SubUserProfile _profile;
  bool _edited = false;

  String _currentPrompt = 'What was a lesson your mom taught you that you\'ll always remember?';
  bool _regenLoading = false;
  
  late final QdrantProfileService _profileService;
  late final PromptGenerationService _promptService;
  late final StoryContinuationService _continuationService;
  
  List<String> _usedPrompts = [];
  
  // Add refresh keys for FutureBuilders
  Key _quickStatsKey = UniqueKey();
  Key _storyContinuationKey = UniqueKey();
  Key _recentActivityKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _profile = widget.profile;
    
    _profileService = QdrantProfileService();
    _promptService = PromptGenerationService(_profileService);
    _continuationService = StoryContinuationService(_profileService);
    
    WidgetsBinding.instance.addObserver(this);
    _loadInitialPrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when app comes back to foreground
    if (state == AppLifecycleState.resumed && _selectedIndex == 0) {
      _refreshHomeData();
    }
  }

  void _refreshHomeData() {
    print('DEBUG: Refreshing home page data');
    if (mounted) {
      setState(() {
        _quickStatsKey = UniqueKey();
        _storyContinuationKey = UniqueKey();
        _recentActivityKey = UniqueKey();
      });
    }
  }


  void _onNavTap(int index) {
    final previousIndex = _selectedIndex;
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    
    // Refresh home data when returning to home tab from record tab
    if (index == 0 && previousIndex == 1) {
      print('DEBUG: Returning to home tab from record tab - refreshing data');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _refreshHomeData();
        }
      });
    }
  }

  void _goToRecordTab() {
    _onNavTap(1);
  }

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(profile: _profile),
      ),
    );
    if (result == true) {
      final updated = await SubUserProfileStorage().getProfiles();
      final newProfile = updated.firstWhere((p) => p.id == _profile.id, orElse: () => _profile);
      if (mounted) {
        setState(() {
          _profile = newProfile;
          _edited = true;
        });
      }
    }
  }

  void _handleBack() {
    if (_edited) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadInitialPrompt() async {
    try {
      final recordings = await _profileService.getAllRecordings(_profile.id);
      
      String initialPrompt;
      if (recordings.isEmpty) {
        // First time user - use a welcoming prompt
        initialPrompt = "Let's start with something meaningful. Tell me about a moment from your childhood that still makes you smile.";
      } else {
        // Always generate diverse prompts for new stories (not follow-ups)
        initialPrompt = await _promptService.generateDiversePrompt(
          profileId: _profile.id,
          usedCategories: _getUsedCategories(recordings),
        );
      }
      
      if (mounted) {
        setState(() {
          _currentPrompt = initialPrompt;
          _usedPrompts.add(initialPrompt);
        });
      }
    } catch (e) {
      print('Error loading initial prompt: $e');
      // Keep default prompt
    }
  }

  Future<void> _regeneratePrompt() async {
    if (mounted) {
      setState(() { _regenLoading = true; });
    }
    
    try {
      final recordings = await _profileService.getAllRecordings(_profile.id);
      String newPrompt;
      
      // Always generate diverse prompts for new stories from the main prompt
      newPrompt = await _promptService.generateDiversePrompt(
        profileId: _profile.id,
        usedCategories: _getUsedCategories(recordings),
      );
      
      if (mounted) {
        setState(() {
          _currentPrompt = newPrompt;
          _usedPrompts.add(newPrompt);
          _regenLoading = false;
        });
      }
    } catch (e) {
      print('Error regenerating prompt: $e');
      if (mounted) {
        setState(() {
          _regenLoading = false;
        });
      }
    }
  }
  
  List<String> _getUsedCategories(List<Map<String, dynamic>> recordings) {
    // Use the same predefined categories as the mosaic view for consistency
    const predefinedCategories = [
      'love', 'family', 'career', 'wisdom', 'friends', 'education', 
      'health', 'adventure', 'loss', 'growth'
    ];
    
    final usedCategories = <String>{};
    print('DEBUG Dashboard: Processing ${recordings.length} recordings for categories');
    
    for (final recording in recordings) {
      final recordingCategories = recording['categories'] as List<dynamic>? ?? [];
      final uuid = recording['uuid'] ?? 'unknown';
      print('DEBUG Dashboard: Recording $uuid has categories: $recordingCategories');
      
      for (final category in recordingCategories.cast<String>()) {
        if (predefinedCategories.contains(category)) {
          usedCategories.add(category);
          print('DEBUG Dashboard: Added category: $category');
        } else {
          print('DEBUG Dashboard: Skipped non-predefined category: $category');
        }
      }
    }
    
    print('DEBUG Dashboard: Final used categories: ${usedCategories.toList()}');
    return usedCategories.toList();
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
          _buildPromptCard(),
          const SizedBox(height: 24),
          _buildActionTiles(),
          const SizedBox(height: 24),
          _buildStoryContinuationSection(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
          const SizedBox(height: 80), // Extra space for bottom nav
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
            ),
            child: _profile.profileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      _profile.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 30,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 30,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile.name,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to capture another memory?',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _quickStatsKey,
      future: _profileService.getAllRecordings(_profile.id),
      builder: (context, snapshot) {
        final recordings = snapshot.data ?? [];
        final categories = _getUsedCategories(recordings);
        final thisWeek = recordings.where((r) {
          final date = DateTime.tryParse(r['date'] ?? '');
          if (date == null) return false;
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          return date.isAfter(weekAgo);
        }).length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Memories',
                recordings.length.toString(),
                Icons.auto_stories_outlined,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                thisWeek.toString(),
                Icons.calendar_today_outlined,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Categories',
                categories.length.toString(),
                Icons.category_outlined,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headline.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkIndigo.withOpacity(0.05),
            darkIndigo.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: darkIndigo.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkIndigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lightbulb_outline, color: darkIndigo, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Memory Prompt',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: darkIndigo,
                      ),
                    ),
                    Text(
                      'AI-generated just for you',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _regenLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(darkIndigo),
                        ),
                      )
                    : Icon(Icons.refresh, color: darkIndigo, size: 20),
                tooltip: 'Generate New Prompt',
                onPressed: _regenLoading ? null : _regeneratePrompt,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentPrompt,
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic, size: 20),
              label: const Text('Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: _goToRecordTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.headline.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                'Timeline',
                'View your memories',
                Icons.timeline,
                Colors.purple,
                () => _pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                'Archive',
                'Browse all stories',
                Icons.archive_outlined,
                Colors.teal,
                () => _pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.border.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.label.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _recentActivityKey,
      future: _profileService.getAllRecordings(_profile.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentRecordings = snapshot.data!
            .take(3)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Memories',
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => _pageController.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Text(
                    'View All',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recentRecordings.map((recording) => _buildRecentActivityItem(recording)),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivityItem(Map<String, dynamic> recording) {
    final summary = recording['personalized_summary'] ?? recording['summary'] ?? '';
    final date = DateTime.tryParse(recording['date'] ?? '') ?? DateTime.now();
    final categories = (recording['categories'] as List<dynamic>? ?? [])
        .cast<String>()
        .take(2)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.length > 60 ? '${summary.substring(0, 60)}...' : summary,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categories.first,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContinuationSection() {
    return FutureBuilder<Map<int, List<Map<String, dynamic>>>>(
      key: _storyContinuationKey,
      future: _profileService.getTimelineData(_profile.id),
      builder: (context, snapshot) {
        print('DEBUG: Story continuation snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.hasError) {
          print('DEBUG: Error loading timeline stories: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        // Extract all stories from timeline data and filter expandable ones
        final timelineData = snapshot.data!;
        final allStories = <Map<String, dynamic>>[];
        for (final yearStories in timelineData.values) {
          allStories.addAll(yearStories);
        }
        
        // Filter for stories that can be expanded (have sessions and content)
        final expandableStories = allStories.where((story) {
          final hasContent = (story['summary']?.toString().isNotEmpty == true);
          final sessionCount = story['session_count'] ?? 1;
          return hasContent && sessionCount >= 1;
        }).toList();
        
        print('DEBUG: Found ${expandableStories.length} expandable stories from timeline data');
        
        if (expandableStories.isEmpty) {
          print('DEBUG: No expandable stories available');
          return const SizedBox.shrink();
        }

        final limitedStories = expandableStories.take(3).toList(); // Show top 3
        print('DEBUG: Showing ${limitedStories.length} expandable stories');
        
        // Debug: Print session counts for verification
        for (final story in limitedStories) {
          final uuid = story['uuid'] ?? 'unknown';
          final sessionCount = story['session_count'] ?? 1;
          final summary = story['summary'] ?? '';
          print('DEBUG: Story $uuid has $sessionCount sessions - ${summary.length > 30 ? summary.substring(0, 30) + '...' : summary}');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue Your Stories',
              style: AppTextStyles.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.border.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_stories, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expand Your Memories',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Add more details to existing stories',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add more details to an existing story with a follow-up prompt:',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ...limitedStories.map((story) => _buildStoryTile(story)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStoryTile(Map<String, dynamic> story) {
    final summary = story['personalized_summary'] ?? story['summary'] ?? '';
    final year = story['year']?.toString() ?? '';
    final sessionCount = story['session_count'] ?? 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handleStoryContinuation(story),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.length > 50 ? '${summary.substring(0, 50)}...' : summary,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (year.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              year,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 10,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$sessionCount session${sessionCount > 1 ? 's' : ''}',
                            style: AppTextStyles.label.copyWith(
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStoryContinuation(Map<String, dynamic> story) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      print('DEBUG: Generating continuation prompt for story: ${story['uuid']}');
      print('DEBUG: Story data: ${story.toString()}');

      // Get the complete story data with all sessions
      final completeStory = await _continuationService.getConsolidatedStory(
        _profile.id,
        story['uuid'],
      );

      // Generate a continuation prompt for this specific story
      final continuationPrompt = await _promptService.generateContinuationPrompt(
        profileId: _profile.id,
        existingStory: completeStory ?? story,
      );

      print('DEBUG: Generated continuation prompt: $continuationPrompt');

      // Hide loading dialog
      Navigator.of(context).pop();

      // Navigate to record page with the continuation prompt and story context
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordPage(
            prompt: continuationPrompt,
            profileId: _profile.id,
            isStoryContinuation: true,
            originalStoryUuid: story['uuid'],
            storyContext: completeStory,
          ),
        ),
      );
      
      // Refresh data when returning from recording
      if (result != null) {
        print('DEBUG: Returned from story continuation recording - refreshing data');
        _refreshHomeData();
      }
    } catch (e) {
      // Hide loading dialog if still showing
      Navigator.of(context).pop();
      
      print('Error generating continuation prompt: $e');
      
      // Show fallback prompt with story context
      final fallbackPrompt = _generateFallbackContinuationPrompt(story);
      
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordPage(
            prompt: fallbackPrompt,
            profileId: _profile.id,
            isStoryContinuation: true,
            originalStoryUuid: story['uuid'],
            storyContext: null, // No context available in error case
          ),
        ),
      );
      
      // Refresh data when returning from recording
      if (result != null) {
        print('DEBUG: Returned from fallback story continuation recording - refreshing data');
        _refreshHomeData();
      }
    }
  }

  String _generateFallbackContinuationPrompt(Map<String, dynamic> story) {
    final transcript = story['transcript'] ?? '';
    final originalPrompt = story['prompt'] ?? '';
    final summary = story['personalized_summary'] ?? story['summary'] ?? '';
    
    // Use the actual transcript first - it's most specific
    if (transcript.isNotEmpty) {
      final firstSentence = transcript.split('.').first.trim();
      return "You mentioned: \"$firstSentence\". Can you tell me more details about that experience? What else do you remember about it?";
    } else if (originalPrompt.isNotEmpty) {
      return "Tell me more about $originalPrompt. What other details do you remember about that experience?";
    } else if (summary.isNotEmpty) {
      final summaryWords = summary.split(' ').take(8).join(' ');
      return "Earlier you shared: \"$summaryWords...\". Can you tell me more details about that story?";
    } else {
      return "Tell me more details about that story you shared earlier.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: _handleBack,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _profile.name.toUpperCase(),
                  style: AppTextStyles.headline.copyWith(fontSize: 24),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.textPrimary),
              onPressed: _editProfile,
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (mounted) {
              setState(() => _selectedIndex = index);
            }
          },
          children: [
            // Home Tab - Modern Dashboard
            _buildDashboardHome(),
            // Record Tab
            RecordPage(prompt: _currentPrompt, profileId: _profile.id),
            // Timeline Tab
            TimelinePage(profile: _profile),
            // Archive Tab
            ArchivePage(profileId: _profile.id),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkIndigo,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Timeline'),
          BottomNavigationBarItem(icon: Icon(Icons.archive), label: 'Archive'),
        ],
      ),
    );
  }
} 