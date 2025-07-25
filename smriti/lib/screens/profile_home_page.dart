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

class _ProfileHomePageState extends State<ProfileHomePage> {
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _profile = widget.profile;
    
    _profileService = QdrantProfileService();
    _promptService = PromptGenerationService(_profileService);
    _continuationService = StoryContinuationService(_profileService);
    
    _loadInitialPrompt();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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
      setState(() {
        _profile = newProfile;
        _edited = true;
      });
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
      
      setState(() {
        _currentPrompt = initialPrompt;
        _usedPrompts.add(initialPrompt);
      });
    } catch (e) {
      print('Error loading initial prompt: $e');
      // Keep default prompt
    }
  }

  Future<void> _regeneratePrompt() async {
    setState(() { _regenLoading = true; });
    
    try {
      final recordings = await _profileService.getAllRecordings(_profile.id);
      String newPrompt;
      
      // Always generate diverse prompts for new stories from the main prompt
      newPrompt = await _promptService.generateDiversePrompt(
        profileId: _profile.id,
        usedCategories: _getUsedCategories(recordings),
      );
      
      setState(() {
        _currentPrompt = newPrompt;
        _usedPrompts.add(newPrompt);
        _regenLoading = false;
      });
    } catch (e) {
      print('Error regenerating prompt: $e');
      setState(() {
        _regenLoading = false;
      });
    }
  }
  
  List<String> _getUsedCategories(List<Map<String, dynamic>> recordings) {
    final categories = <String>{};
    for (final recording in recordings) {
      final recordingCategories = recording['categories'] as List<dynamic>? ?? [];
      categories.addAll(recordingCategories.cast<String>());
    }
    return categories.toList();
  }

  Widget _buildStoryContinuationSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _continuationService.findExpandableStories(_profile.id),
      builder: (context, snapshot) {
        print('DEBUG: Story continuation snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.hasError) {
          print('DEBUG: Error loading expandable stories: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final expandableStories = snapshot.data!;
        print('DEBUG: Found ${expandableStories.length} expandable stories');
        
        if (expandableStories.isEmpty) {
          print('DEBUG: No expandable stories available');
          return const SizedBox.shrink();
        }

        final limitedStories = expandableStories.take(3).toList(); // Show top 3
        print('DEBUG: Showing ${limitedStories.length} expandable stories');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_stories, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Continue a Story',
                        style: AppTextStyles.label.copyWith(fontSize: 16),
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
          ),
        );
      },
    );
  }

  Widget _buildStoryTile(Map<String, dynamic> story) {
    final summary = story['personalized_summary'] ?? story['summary'] ?? '';
    final prompt = story['prompt'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        tileColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: summary.isNotEmpty
            ? Text(
                summary.length > 80 ? '${summary.substring(0, 80)}...' : summary,
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Icon(Icons.add_circle_outline, color: AppColors.primary),
        onTap: () => _continueStory(story),
      ),
    );
  }

  Future<void> _continueStory(Map<String, dynamic> story) async {
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
      Navigator.of(context).push(
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
    } catch (e) {
      // Hide loading dialog if still showing
      Navigator.of(context).pop();
      
      print('Error generating continuation prompt: $e');
      
      // Show fallback prompt with story context
      final fallbackPrompt = _generateFallbackContinuationPrompt(story);
      
      Navigator.of(context).push(
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
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            // Home Tab
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: Colors.white,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Start a New Story', style: AppTextStyles.label.copyWith(fontSize: 16)),
                                      Text('Explore a new memory or experience', 
                                           style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  IconButton(
                                    icon: _regenLoading
                                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Icon(Icons.refresh, color: AppColors.primary),
                                    tooltip: 'Generate New Prompt',
                                    onPressed: _regenLoading ? null : _regeneratePrompt,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentPrompt,
                                style: AppTextStyles.headline.copyWith(fontSize: 20, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: Icon(Icons.mic),
                                label: Text('Start Recording'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkIndigo,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                onPressed: _goToRecordTab,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildStoryContinuationSection(),
                  ],
                ),
              ),
            ),
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