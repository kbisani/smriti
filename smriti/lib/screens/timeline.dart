import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import '../storage/qdrant_profile_service.dart';
import 'story_sessions_page.dart';

class _MosaicStory {
  final String summary;
  final int? year;
  final List<String> categories;
  final String? personalizedSummary;
  final String? uuid;
  final int? sessionCount;
  final List<Map<String, dynamic>>? sessions;
  final String? originalPrompt;
  final String? consolidatedSummary;
  _MosaicStory({
    required this.summary, 
    this.year, 
    required this.categories, 
    this.personalizedSummary,
    this.uuid,
    this.sessionCount,
    this.sessions,
    this.originalPrompt,
    this.consolidatedSummary,
  });
}

class _TimelineEntry {
  final int year;
  final String summary;
  final String? uuid;
  final int? sessionCount;
  final List<Map<String, dynamic>>? sessions;
  final String? originalPrompt;
  final String? consolidatedSummary;
  _TimelineEntry({
    required this.year, 
    required this.summary, 
    this.uuid,
    this.sessionCount,
    this.sessions,
    this.originalPrompt,
    this.consolidatedSummary,
  });
}

class TimelinePage extends StatefulWidget {
  final SubUserProfile profile;
  const TimelinePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final QdrantProfileService _profileService;

  static const List<String> _predefinedCategories = [
    'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileService = QdrantProfileService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<int, List<_TimelineEntry>>> _loadTimelineEntries() async {
    try {
      final timelineData = await _profileService.getTimelineData(widget.profile.id);
      final Map<int, List<_TimelineEntry>> byYear = {};
      
      // Convert the timeline data to _TimelineEntry objects
      timelineData.forEach((year, entries) {
        byYear[year] = entries.map((entry) => _TimelineEntry(
          year: entry['year'],
          summary: entry['summary'],
          uuid: entry['uuid'],
          sessionCount: entry['session_count'],
          sessions: entry['sessions'] != null 
              ? List<Map<String, dynamic>>.from(entry['sessions'])
              : null,
          originalPrompt: entry['original_prompt'],
          consolidatedSummary: entry['consolidated_summary'],
        )).toList();
      });
      
      // Integrate birth event into timeline
      final birthYear = widget.profile.birthDate?.year;
      final birthPlace = widget.profile.birthPlace ?? 'Place?';
      if (birthYear != null) {
        byYear.putIfAbsent(birthYear, () => []).insert(
          0,
          _TimelineEntry(year: birthYear, summary: 'Born in $birthPlace'),
        );
      }
      
      return byYear;
    } catch (e) {
      print('Error loading timeline entries: $e');
      return {};
    }
  }

  Future<Map<String, List<_MosaicStory>>> _loadMosaicStories() async {
    try {
      final mosaicData = await _profileService.getMosaicData(widget.profile.id);
      final Map<String, List<_MosaicStory>> byCategory = {};
      
      // Initialize categories
      for (var c in _predefinedCategories) {
        byCategory[c] = [];
      }
      
      // Convert the mosaic data to _MosaicStory objects
      mosaicData.forEach((category, stories) {
        byCategory[category] = stories.map((story) => _MosaicStory(
          summary: story['summary'],
          year: story['year'],
          categories: List<String>.from(story['categories']),
          personalizedSummary: story['personalizedSummary'],
          uuid: story['uuid'],
          sessionCount: story['session_count'],
          sessions: story['sessions'] != null 
              ? List<Map<String, dynamic>>.from(story['sessions'])
              : null,
          originalPrompt: story['original_prompt'],
          consolidatedSummary: story['consolidated_summary'],
        )).toList();
      });
      
      return byCategory;
    } catch (e) {
      print('Error loading mosaic stories: $e');
      return { for (var c in _predefinedCategories) c: <_MosaicStory>[] };
    }
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
                    FutureBuilder<Map<int, List<_TimelineEntry>>>(
                      future: _loadTimelineEntries(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final byYear = snapshot.data!;
                        if (byYear.isEmpty) {
                          return Center(child: Text('No stories with a year found.', style: AppTextStyles.subhead));
                        }
                        final sortedYears = byYear.keys.toList()..sort((a, b) => a.compareTo(b)); // Oldest at top
                        return ListView(
                          children: [
                            for (final year in sortedYears) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Text(year.toString(), style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 16)),
                              ),
                              for (final entry in byYear[year]!)
                                GestureDetector(
                                  onTap: () {
                                    if (entry.sessions != null && entry.sessions!.isNotEmpty) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => StorySessionsPage(
                                            storyData: {
                                              'sessions': entry.sessions!,
                                              'summary': entry.summary,
                                              'year': entry.year,
                                              'uuid': entry.uuid,
                                              'session_count': entry.sessionCount ?? 1,
                                              'original_prompt': entry.originalPrompt ?? '',
                                              'consolidated_summary': entry.consolidatedSummary,
                                            },
                                            profileName: widget.profile.name,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Card(
                                    color: AppColors.card,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(entry.summary, style: AppTextStyles.body),
                                              ),
                                              if (entry.sessions != null && entry.sessions!.isNotEmpty)
                                                Icon(Icons.arrow_forward_ios, 
                                                    size: 16, 
                                                    color: AppColors.textSecondary),
                                            ],
                                          ),
                                          if (entry.sessionCount != null && entry.sessionCount! > 1) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${entry.sessionCount} sessions',
                                                style: AppTextStyles.label.copyWith(
                                                  color: AppColors.primary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ]
                          ],
                        );
                      },
                    ),
                    // Graph Tab
                    Center(
                      child: Text('Graph View (coming soon)', style: AppTextStyles.body),
                    ),
                    // Mosaic Tab
                    FutureBuilder<Map<String, List<_MosaicStory>>>(
                      future: _loadMosaicStories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final byCategory = snapshot.data!;
                        final categoriesWithStories = _predefinedCategories.where((cat) => byCategory[cat]!.isNotEmpty).toList();
                        if (categoriesWithStories.isEmpty) {
                          return Center(child: Text('No stories with categories found.', style: AppTextStyles.subhead));
                        }
                        return GridView.builder(
                          itemCount: categoriesWithStories.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                          itemBuilder: (context, idx) {
                            final cat = categoriesWithStories[idx];
                            final stories = byCategory[cat]!;
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryStoriesPage(category: cat, stories: stories, profile: widget.profile),
                                  ),
                                );
                              },
                              child: Card(
                                color: AppColors.card,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 2,
                                shadowColor: AppColors.border.withOpacity(0.18),
                                child: Padding(
                                  padding: const EdgeInsets.all(18.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        cat[0].toUpperCase() + cat.substring(1),
                                        style: AppTextStyles.label.copyWith(fontSize: 20, fontFamily: 'Serif', color: AppColors.primary),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${stories.length} stor${stories.length == 1 ? 'y' : 'ies'}',
                                        style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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

// Add this new page for category stories
class CategoryStoriesPage extends StatelessWidget {
  final String category;
  final List<_MosaicStory> stories;
  final SubUserProfile? profile;
  const CategoryStoriesPage({required this.category, required this.stories, this.profile, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text(
          category[0].toUpperCase() + category.substring(1),
          style: AppTextStyles.headline.copyWith(fontSize: 22, color: AppColors.primary, fontFamily: 'Serif'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: stories.isEmpty
            ? Center(child: Text('No stories found.', style: AppTextStyles.subhead))
            : GridView.builder(
                itemCount: stories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, idx) {
                  final story = stories[idx];
                  return GestureDetector(
                    onTap: () {
                      if (story.sessions != null && story.sessions!.isNotEmpty && story.uuid != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => StorySessionsPage(
                              storyData: {
                                'sessions': story.sessions!,
                                'summary': story.summary,
                                'year': story.year,
                                'uuid': story.uuid,
                                'session_count': story.sessionCount ?? 1,
                                'original_prompt': story.originalPrompt ?? '',
                                'consolidated_summary': story.consolidatedSummary,
                              },
                              profileName: profile?.name ?? 'Profile',
                            ),
                          ),
                        );
                      }
                    },
                    child: Card(
                      color: AppColors.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      shadowColor: AppColors.border.withOpacity(0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (story.year != null)
                                  Text(story.year.toString(), style: AppTextStyles.label.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                                const Spacer(),
                                if (story.sessions != null && story.sessions!.isNotEmpty)
                                  Icon(Icons.arrow_forward_ios, 
                                      size: 12, 
                                      color: AppColors.textSecondary),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                story.summary,
                                style: AppTextStyles.body,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 4,
                              ),
                            ),
                            if (story.sessionCount != null && story.sessionCount! > 1) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${story.sessionCount} sessions',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
