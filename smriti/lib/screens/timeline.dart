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


  // Filter states
  int? _selectedYear;
  int? _minSessionCount;
  bool _showFilters = false;

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
      const predefinedCategories = [
        'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
      ];
      for (var c in predefinedCategories) {
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
      const predefinedCategories = [
        'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
      ];
      return { for (var c in predefinedCategories) c: <_MosaicStory>[] };
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
                    Column(
                      children: [
                        // Filter controls
                        _buildFilterControls(),
                        
                        // Timeline content
                        Expanded(
                          child: FutureBuilder<Map<int, List<_TimelineEntry>>>(
                            future: _loadTimelineEntries(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }
                              final byYear = snapshot.data!;
                              if (byYear.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timeline, size: 64, color: AppColors.textSecondary),
                                      const SizedBox(height: 16),
                                      Text('No dated stories found', style: AppTextStyles.subhead),
                                      const SizedBox(height: 8),
                                      Text('Add year information to stories to see them here', 
                                           style: AppTextStyles.label),
                                    ],
                                  ),
                                );
                              }
                              
                              // Apply filters
                              final filteredByYear = _applyFilters(byYear);
                              final years = filteredByYear.keys.toList()..sort((a, b) => b.compareTo(a));
                              
                              if (years.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.filter_list_off, size: 64, color: AppColors.textSecondary),
                                      const SizedBox(height: 16),
                                      Text('No stories match your filters', style: AppTextStyles.subhead),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _clearFilters,
                                        child: Text('Clear filters'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              return _buildVisualTimeline(filteredByYear, years);
                            },
                          ),
                        ),
                      ],
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
                        const predefinedCategories = [
                          'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
                        ];
                        final categoriesWithStories = predefinedCategories.where((cat) => byCategory[cat]!.isNotEmpty).toList();
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

  // Filter Controls
  Widget _buildFilterControls() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showFilters ? null : 60,
      child: Column(
        children: [
          // Filter toggle row
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.profile.name}\'s Timeline',
                  style: AppTextStyles.headline.copyWith(fontSize: 20),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                  color: (_selectedYear != null || _minSessionCount != null) 
                      ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
                tooltip: 'Filter stories',
              ),
            ],
          ),
          
          // Expandable filter options
          if (_showFilters) ...[ 
            const Divider(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Year filter  
                ChoiceChip(
                  label: Text(_selectedYear?.toString() ?? 'All Years'),
                  selected: _selectedYear != null,
                  onSelected: (selected) {
                    if (selected) {
                      _showYearPicker();
                    } else {
                      setState(() => _selectedYear = null);
                    }
                  },
                ),
                
                // Session count filter
                ChoiceChip(
                  label: Text(_minSessionCount != null ? '${_minSessionCount}+ sessions' : 'All Sessions'),
                  selected: _minSessionCount != null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _minSessionCount = 2);
                    } else {
                      setState(() => _minSessionCount = null);
                    }
                  },
                ),
                
                // Clear filters
                if (_selectedYear != null || _minSessionCount != null)
                  ActionChip(
                    label: Text('Clear All'),
                    onPressed: _clearFilters,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    labelStyle: TextStyle(color: Colors.red[700]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // Visual Timeline Builder
  Widget _buildVisualTimeline(Map<int, List<_TimelineEntry>> filteredByYear, List<int> years) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 32, right: 16, top: 16),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final entries = filteredByYear[year]!;
        final isLastYear = index == years.length - 1;
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line and year marker
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    // Year bubble
                    Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          year.toString(),
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    
                    // Timeline line
                    if (!isLastYear)
                      Expanded(
                        child: Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Stories for this year
              Expanded(
                child: Column(
                  children: entries.map((entry) => _buildTimelineStoryCard(entry)).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Enhanced Story Card
  Widget _buildTimelineStoryCard(_TimelineEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => _navigateToStory(entry),
        child: Card(
          elevation: 4,
          shadowColor: AppColors.border.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.card,
                  AppColors.card.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Story summary
                Text(
                  entry.summary,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Metadata row
                Row(
                  children: [
                    // Session count badge
                    if (entry.sessionCount != null && entry.sessionCount! > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.layers, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.sessionCount} sessions',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Navigation arrow
                    if (entry.sessions != null && entry.sessions!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Methods
  Map<int, List<_TimelineEntry>> _applyFilters(Map<int, List<_TimelineEntry>> byYear) {
    if (_selectedYear == null && _minSessionCount == null) {
      return byYear;
    }
    
    final filtered = <int, List<_TimelineEntry>>{};
    
    byYear.forEach((year, entries) {
      if (_selectedYear != null && year != _selectedYear) return;
      
      final filteredEntries = entries.where((entry) {
        // Session count filter
        if (_minSessionCount != null) {
          final sessionCount = entry.sessionCount ?? 1;
          if (sessionCount < _minSessionCount!) return false;
        }
        
        return true;
      }).toList();
      
      if (filteredEntries.isNotEmpty) {
        filtered[year] = filteredEntries;
      }
    });
    
    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _selectedYear = null;
      _minSessionCount = null;
    });
  }


  void _showYearPicker() async {
    final timelineData = await _loadTimelineEntries();
    final years = timelineData.keys.toList()..sort();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Year'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: years.map((year) {
              return ListTile(
                title: Text(year.toString()),
                onTap: () {
                  setState(() => _selectedYear = year);
                  Navigator.pop(context);
                },
                selected: _selectedYear == year,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToStory(_TimelineEntry entry) {
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
