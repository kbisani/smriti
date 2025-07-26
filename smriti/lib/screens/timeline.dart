import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import '../storage/qdrant_profile_service.dart';
import 'story_sessions_page.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  
  // Graph tab states
  bool _isNetworkView = true; // true = network graph, false = emotional landscape
  
  // Sentiment analysis cache to avoid repeated API calls
  final Map<String, double> _sentimentCache = {};

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
                    Column(
                      children: [
                        // Graph view toggle
                        _buildGraphViewToggle(),
                        
                        // Graph content
                        Expanded(
                          child: FutureBuilder<Map<int, List<_TimelineEntry>>>(
                            future: _loadTimelineEntries(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }
                              final timelineData = snapshot.data!;
                              final allEntries = timelineData.values.expand((e) => e).toList();
                              
                              if (allEntries.isEmpty) {
                                return _buildGraphEmptyState();
                              }
                              
                              return _isNetworkView
                                  ? _buildMemoryNetworkGraph(allEntries)
                                  : _buildEmotionalLandscape(allEntries);
                            },
                          ),
                        ),
                      ],
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

  // Graph View Toggle
  Widget _buildGraphViewToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Explore Connections',
              style: AppTextStyles.headline.copyWith(fontSize: 20),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.hub_outlined,
                    color: _isNetworkView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isNetworkView = true),
                  tooltip: 'Memory Network',
                ),
                IconButton(
                  icon: Icon(
                    Icons.trending_up,
                    color: !_isNetworkView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isNetworkView = false),
                  tooltip: 'Emotional Landscape',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGraphEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No memories to visualize',
            style: AppTextStyles.subhead,
          ),
          const SizedBox(height: 8),
          Text(
            'Add dated memories to see connections and patterns',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryNetworkGraph(List<_TimelineEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reflection Patterns',
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover when you reflect on different periods of your life',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildReflectionPatterns(entries),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmotionalLandscape(List<_TimelineEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotional Landscape',
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visualize the emotional journey through your memories over time',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildEmotionalVisualization(entries),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReflectionPatterns(List<_TimelineEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No reflection patterns yet',
              style: AppTextStyles.subhead,
            ),
            const SizedBox(height: 8),
            Text(
              'Add more memories to see when you reflect on different life periods',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Each dot shows when you recorded a memory about a specific year',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Reflection matrix
          _buildReflectionMatrix(entries),
          
          const SizedBox(height: 24),
          
          // Insights summary
          _buildReflectionInsights(entries),
          
          const SizedBox(height: 32),
          
          // Story Length Visualization
          _buildStoryLengthVisualization(entries),
        ],
      ),
    );
  }

  Widget _buildReflectionMatrix(List<_TimelineEntry> entries) {
    // Group memories by the year they're about
    final Map<int, List<_TimelineEntry>> memoriesByYear = {};
    for (final entry in entries) {
      memoriesByYear.putIfAbsent(entry.year, () => []).add(entry);
    }

    final years = memoriesByYear.keys.toList()..sort();
    if (years.isEmpty) return const SizedBox.shrink();

    // For demo purposes, assume memories were recorded recently (2024)
    // In a real app, you'd have created_at timestamps
    final currentYear = DateTime.now().year;

    return Container(
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reflection Timeline',
            style: AppTextStyles.headline.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 16),
          
          // Y-axis label (recording year)
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Recorded in',
                  style: AppTextStyles.label.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Memory about year →',
                    style: AppTextStyles.label.copyWith(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y-axis (recording years)
                SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildYearLabel('$currentYear'),
                      _buildYearLabel('${currentYear - 1}'),
                      _buildYearLabel('${currentYear - 2}'),
                    ],
                  ),
                ),
                
                // Matrix grid
                Expanded(
                  child: _buildReflectionGrid(years, memoriesByYear, currentYear),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearLabel(String year) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        year,
        style: AppTextStyles.label.copyWith(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReflectionGrid(List<int> years, Map<int, List<_TimelineEntry>> memoriesByYear, int currentYear) {
    return Column(
      children: [
        // X-axis (memory years)
        Container(
          height: 30,
          child: Row(
            children: years.map((year) => Expanded(
              child: Center(
                child: Text(
                  year.toString(),
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        
        // Grid rows
        Expanded(
          child: Column(
            children: [
              // Row for current year recordings
              Expanded(child: _buildGridRow(years, memoriesByYear, currentYear, 'current')),
              // Row for last year recordings  
              Expanded(child: _buildGridRow(years, memoriesByYear, currentYear - 1, 'last')),
              // Row for two years ago recordings
              Expanded(child: _buildGridRow(years, memoriesByYear, currentYear - 2, 'older')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridRow(List<int> years, Map<int, List<_TimelineEntry>> memoriesByYear, int recordingYear, String period) {
    return Row(
      children: years.map((memoryYear) {
        final memories = memoriesByYear[memoryYear] ?? [];
        
        // For demo, simulate when memories might have been recorded
        // In real app, you'd use actual created_at timestamps
        final recordedMemories = _simulateRecordingDistribution(memories, memoryYear, recordingYear);
        
        final intensity = recordedMemories / 5.0; // Normalize to 0-1
        final color = _getReflectionColor(intensity, memoryYear, recordingYear);
        
        return Expanded(
          child: GestureDetector(
            onTap: () => _showReflectionDetails(memoryYear, recordingYear, memories),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: recordedMemories > 0 
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: recordedMemories > 0
                    ? Text(
                        recordedMemories.toString(),
                        style: AppTextStyles.label.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  int _simulateRecordingDistribution(List<_TimelineEntry> memories, int memoryYear, int recordingYear) {
    if (memories.isEmpty) return 0;
    
    final currentYear = DateTime.now().year;
    final yearGap = currentYear - memoryYear;
    
    // Simulate realistic reflection patterns
    if (recordingYear == currentYear) {
      // Recent memories more likely to be recorded recently
      if (yearGap <= 2) return memories.length;
      if (yearGap <= 5) return (memories.length * 0.7).round();
      return (memories.length * 0.4).round();
    } else if (recordingYear == currentYear - 1) {
      // Some distributed reflection
      if (yearGap <= 5) return (memories.length * 0.3).round();
      return (memories.length * 0.2).round();
    } else {
      // Older recordings - fewer memories
      return (memories.length * 0.1).round();
    }
  }

  Color _getReflectionColor(double intensity, int memoryYear, int recordingYear) {
    if (intensity == 0) return AppColors.card;
    
    // Different colors for different patterns
    final currentYear = DateTime.now().year;
    final yearGap = recordingYear - memoryYear;
    
    if (yearGap <= 2) {
      // Recent reflection - blue tones
      return Colors.blue.withOpacity(0.3 + intensity * 0.7);
    } else if (yearGap <= 10) {
      // Medium-term reflection - green tones
      return Colors.green.withOpacity(0.3 + intensity * 0.7);
    } else {
      // Long-term reflection - purple tones
      return Colors.purple.withOpacity(0.3 + intensity * 0.7);
    }
  }

  Widget _buildReflectionInsights(List<_TimelineEntry> entries) {
    final insights = _generateReflectionInsights(entries);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Reflection Insights',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTextStyles.body.copyWith(color: AppColors.primary)),
                Expanded(
                  child: Text(
                    insight,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<String> _generateReflectionInsights(List<_TimelineEntry> entries) {
    final insights = <String>[];
    
    // Group by year to analyze patterns
    final Map<int, List<_TimelineEntry>> byYear = {};
    for (final entry in entries) {
      byYear.putIfAbsent(entry.year, () => []).add(entry);
    }
    
    final years = byYear.keys.toList()..sort();
    if (years.isEmpty) return ['No memories to analyze yet.'];
    
    final currentYear = DateTime.now().year;
    final recentYears = years.where((y) => currentYear - y <= 3).length;
    final olderYears = years.where((y) => currentYear - y > 3).length;
    
    if (recentYears > olderYears) {
      insights.add('You tend to reflect more on recent experiences');
    } else if (olderYears > recentYears) {
      insights.add('You often revisit memories from earlier in your life');
    }
    
    // Find most reflected-on year
    final mostMemories = byYear.entries.reduce((a, b) => 
        a.value.length > b.value.length ? a : b);
    insights.add('${mostMemories.key} has the most memories (${mostMemories.value.length})');
    
    // Analyze time span
    final yearSpan = years.last - years.first;
    if (yearSpan > 10) {
      insights.add('Your memories span ${yearSpan} years of life experiences');
    }
    
    return insights;
  }

  void _showReflectionDetails(int memoryYear, int recordingYear, List<_TimelineEntry> memories) {
    if (memories.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$memoryYear Memories'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Memories about $memoryYear',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...memories.take(5).map((memory) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${memory.summary}',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                ),
              )),
              if (memories.length > 5)
                Text(
                  '... and ${memories.length - 5} more',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryLengthVisualization(List<_TimelineEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.format_size, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Story Detail Levels',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'See how detailed your memories are across different years',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bubble size = story detail level • Color = year',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bubble chart with fullscreen option
          _buildInteractiveBubbleChart(entries),
          
          const SizedBox(height: 16),
          
          // Length insights
          _buildLengthInsights(entries),
        ],
      ),
    );
  }

  Widget _buildInteractiveBubbleChart(List<_TimelineEntry> entries) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header with fullscreen button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bubble_chart, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Story Detail Bubbles',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.fullscreen, color: AppColors.primary, size: 20),
                  onPressed: () => _showFullscreenBubbleChart(entries),
                  tooltip: 'View fullscreen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          // Bubble chart (tap for fullscreen interaction)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => _showFullscreenBubbleChart(entries),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Stack(
                    children: [
                      _buildBubbleChart(entries),
                      // Overlay hint for fullscreen
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Tap for interactive view',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleChart(List<_TimelineEntry> entries) {
    // Calculate story lengths (simulated based on summary length + some variance)
    final bubblesData = entries.map((entry) {
      final baseLength = entry.summary.length;
      final sessionMultiplier = (entry.sessionCount ?? 1) * 0.5;
      final simulatedLength = (baseLength * (1.0 + sessionMultiplier) * (0.8 + math.Random().nextDouble() * 0.4)).round();
      
      return {
        'entry': entry,
        'length': simulatedLength,
        'year': entry.year,
      };
    }).toList();

    // Don't sort by length - keep original order for better distribution
    // bubblesData.sort((a, b) => (b['length'] as int).compareTo(a['length'] as int));

    return CustomPaint(
      painter: StoryBubblePainter(bubblesData),
      child: Container(), // Let it fill available space
    );
  }

  Widget _buildLengthInsights(List<_TimelineEntry> entries) {
    final insights = _generateLengthInsights(entries);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Detail Insights',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 16,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTextStyles.body.copyWith(color: Colors.amber[700])),
                Expanded(
                  child: Text(
                    insight,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<String> _generateLengthInsights(List<_TimelineEntry> entries) {
    final insights = <String>[];
    
    // Group by year and calculate average lengths
    final Map<int, List<int>> lengthsByYear = {};
    for (final entry in entries) {
      final baseLength = entry.summary.length;
      final sessionMultiplier = (entry.sessionCount ?? 1) * 0.5;
      final simulatedLength = (baseLength * (1.0 + sessionMultiplier)).round();
      
      lengthsByYear.putIfAbsent(entry.year, () => []).add(simulatedLength);
    }
    
    if (lengthsByYear.isEmpty) return ['No stories to analyze yet.'];
    
    // Find most/least detailed year
    final yearAverages = lengthsByYear.map((year, lengths) => 
        MapEntry(year, lengths.reduce((a, b) => a + b) / lengths.length));
    
    final mostDetailed = yearAverages.entries.reduce((a, b) => 
        a.value > b.value ? a : b);
    final leastDetailed = yearAverages.entries.reduce((a, b) => 
        a.value < b.value ? a : b);
    
    if (mostDetailed.key != leastDetailed.key) {
      insights.add('${mostDetailed.key} has your most detailed memories');
      insights.add('${leastDetailed.key} memories tend to be more brief');
    }
    
    // Check for multi-session stories
    final multiSession = entries.where((e) => (e.sessionCount ?? 1) > 1).length;
    if (multiSession > 0) {
      insights.add('$multiSession stories have multiple sessions (deeper stories)');
    }
    
    // Overall pattern
    final totalEntries = entries.length;
    final avgLength = yearAverages.values.reduce((a, b) => a + b) / yearAverages.length;
    if (avgLength > 150) {
      insights.add('You tend to tell detailed, rich stories');
    } else if (avgLength < 80) {
      insights.add('You prefer concise, focused memories');
    } else {
      insights.add('You balance detail with brevity in your stories');
    }
    
    return insights;
  }

  void _handleBubbleTap(TapDownDetails details, List<Map<String, dynamic>> bubblesData) {
    // For now, just show the first memory details
    // In a full implementation, you'd calculate which bubble was tapped
    if (bubblesData.isNotEmpty) {
      final entry = bubblesData.first['entry'] as _TimelineEntry;
      _showStoryLengthDetails(entry, bubblesData.first['length'] as int);
    }
  }

  void _showStoryLengthDetails(_TimelineEntry entry, int simulatedLength) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${entry.year} Memory Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getYearColor(entry.year).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_size, color: _getYearColor(entry.year), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated detail level: ${_getDetailLevel(simulatedLength)}',
                    style: AppTextStyles.body.copyWith(
                      color: _getYearColor(entry.year),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              entry.summary,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
            if (entry.sessionCount != null && entry.sessionCount! > 1) ...[
              const SizedBox(height: 12),
              Text(
                '${entry.sessionCount} sessions (multi-part story)',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getYearColor(int year) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[year.hashCode % colors.length];
  }

  String _getDetailLevel(int length) {
    if (length > 200) return 'Very detailed';
    if (length > 150) return 'Detailed';
    if (length > 100) return 'Moderate';
    if (length > 50) return 'Brief';
    return 'Concise';
  }

  void _showFullscreenBubbleChart(List<_TimelineEntry> entries) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Story Detail Levels - Interactive View',
              style: AppTextStyles.headline.copyWith(fontSize: 18),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: AppColors.primary),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline, color: AppColors.primary),
                onPressed: () => _showBubbleChartHelp(),
                tooltip: 'Help',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    border: Border(
                      bottom: BorderSide(color: AppColors.border.withOpacity(0.2)),
                    ),
                  ),
                  child: Text(
                    'Pinch to zoom • Drag to pan • Tap bubbles for details',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Fullscreen bubble chart
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: InteractiveViewer(
                      minScale: 0.3,
                      maxScale: 5.0,
                      constrained: false,
                      child: Container(
                        width: 800, // Larger canvas for fullscreen
                        height: 800,
                        child: CustomPaint(
                          size: Size(800, 800),
                          painter: StoryBubblePainter(_calculateBubblesData(entries)),
                          child: GestureDetector(
                            onTapDown: (details) => _handleBubbleTap(
                              details,
                              _calculateBubblesData(entries),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateBubblesData(List<_TimelineEntry> entries) {
    return entries.map((entry) {
      final baseLength = entry.summary.length;
      final sessionMultiplier = (entry.sessionCount ?? 1) * 0.5;
      final simulatedLength = (baseLength * (1.0 + sessionMultiplier) * (0.8 + math.Random().nextDouble() * 0.4)).round();
      
      return {
        'entry': entry,
        'length': simulatedLength,
        'year': entry.year,
      };
    }).toList();
  }

  void _showBubbleChartHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Bubble Chart Guide'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem('Bubble Size', 'Larger bubbles = more detailed stories'),
            _buildHelpItem('Bubble Color', 'Different colors represent different years'),
            _buildHelpItem('Navigation', 'Pinch to zoom in/out, drag to pan around'),
            _buildHelpItem('Interaction', 'Tap any bubble to see story details'),
            _buildHelpItem('Pattern', 'Look for clusters of large/small bubbles by year'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
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
  
  Widget _buildEmotionalVisualization(List<_TimelineEntry> entries) {
    // Create a simplified emotional timeline
    final sortedEntries = List<_TimelineEntry>.from(entries)
      ..sort((a, b) => a.year.compareTo(b.year));
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Emotional heatmap
          Container(
            height: 300,
            child: _buildEmotionalHeatmap(sortedEntries),
          ),
          const SizedBox(height: 24),
          // Memory cards with emotional indicators
          ...sortedEntries.map((entry) => _buildEmotionalMemoryCard(entry)),
        ],
      ),
    );
  }
  
  
  Widget _buildEmotionalHeatmap(List<_TimelineEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No memories to visualize',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Positive', Colors.green),
              _buildLegendItem('Neutral', AppColors.primary),
              _buildLegendItem('Reflective', Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          // Heatmap grid
          Expanded(
            child: _buildHeatmapGrid(entries),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid(List<_TimelineEntry> entries) {
    // Group entries by year
    final Map<int, List<_TimelineEntry>> entriesByYear = {};
    for (final entry in entries) {
      entriesByYear.putIfAbsent(entry.year, () => []).add(entry);
    }

    final years = entriesByYear.keys.toList()..sort();
    if (years.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: math.min(years.length, 6), // Max 6 columns for readability
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final yearEntries = entriesByYear[year]!;
        return _buildYearHeatmapTile(year, yearEntries);
      },
    );
  }

  Widget _buildYearHeatmapTile(int year, List<_TimelineEntry> entries) {
    return FutureBuilder<List<double>>(
      future: Future.wait(entries.map((e) => _analyzeSentiment(e.summary))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.2)),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final sentiments = snapshot.data!;
        final avgSentiment = sentiments.isNotEmpty
            ? sentiments.reduce((a, b) => a + b) / sentiments.length
            : 0.0;

        final color = _getEmotionColor(avgSentiment);
        final intensity = (avgSentiment.abs() * 0.7 + 0.3).clamp(0.3, 1.0);

        return GestureDetector(
          onTap: () => _showYearDetails(year, entries, avgSentiment),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(intensity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  year.toString(),
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entries.length} ${entries.length == 1 ? 'memory' : 'memories'}',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getSentimentLabel(avgSentiment),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showYearDetails(int year, List<_TimelineEntry> entries, double avgSentiment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$year Memories'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getEmotionColor(avgSentiment).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: _getEmotionColor(avgSentiment),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overall tone: ${_getSentimentLabel(avgSentiment)}',
                      style: AppTextStyles.body.copyWith(
                        color: _getEmotionColor(avgSentiment),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${entries.length} ${entries.length == 1 ? 'Memory' : 'Memories'}:',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...entries.take(5).map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${entry.summary}',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                ),
              )),
              if (entries.length > 5)
                Text(
                  '... and ${entries.length - 5} more',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmotionalMemoryCard(_TimelineEntry entry) {
    return FutureBuilder<double>(
      future: _analyzeSentiment(entry.summary),
      builder: (context, snapshot) {
        final sentiment = snapshot.data ?? 0.0;
        final emotionColor = _getEmotionColor(sentiment);
        
        return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shadowColor: AppColors.border.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: emotionColor, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.year.toString(),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: emotionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getSentimentLabel(sentiment),
                      style: AppTextStyles.label.copyWith(
                        color: emotionColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.summary,
                style: AppTextStyles.body.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
  
  /// Analyze sentiment using OpenAI with caching for better performance
  Future<double> _analyzeSentiment(String text) async {
    // Check cache first to avoid repeated API calls
    final cacheKey = text.length > 100 ? text.substring(0, 100) : text;
    if (_sentimentCache.containsKey(cacheKey)) {
      return _sentimentCache[cacheKey]!;
    }
    
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print('Warning: OpenAI API key not found, falling back to keyword analysis');
        return _analyzeSentimentKeywords(text);
      }
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': '''Analyze the emotional sentiment of this personal memory text and return ONLY a number between -1.0 and 1.0:

-1.0 to -0.6: Very negative (loss, tragedy, severe difficulty)
-0.5 to -0.3: Moderately negative (challenges, setbacks, sadness)
-0.2 to 0.2: Neutral (factual, mixed emotions, learning experiences)
0.3 to 0.5: Moderately positive (accomplishments, good experiences)
0.6 to 1.0: Very positive (joy, love, major achievements, breakthrough moments)

Consider context, emotional intensity, and overall tone. Return ONLY the decimal number.'''
            },
            {
              'role': 'user',
              'content': text
            }
          ],
          'max_tokens': 10,
          'temperature': 0.3,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'].toString().trim();
        final sentiment = double.tryParse(content) ?? 0.0;
        
        // Cache the result
        _sentimentCache[cacheKey] = sentiment.clamp(-1.0, 1.0);
        return _sentimentCache[cacheKey]!;
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        return _analyzeSentimentKeywords(text);
      }
    } catch (e) {
      print('Error analyzing sentiment with OpenAI: $e');
      return _analyzeSentimentKeywords(text);
    }
  }
  
  /// Fallback keyword-based sentiment analysis for when OpenAI is unavailable
  double _analyzeSentimentKeywords(String text) {
    final positiveWords = ['happy', 'joy', 'love', 'success', 'achievement', 'wonderful', 'amazing', 'great', 'beautiful', 
                          'incredible', 'dream', 'accomplished', 'proud', 'perfect', 'fantastic'];
    final negativeWords = ['sad', 'loss', 'difficult', 'devastating', 'terrible', 'awful', 'failed', 'heartbreaking',
                          'scared', 'worried', 'overwhelmed', 'death', 'died', 'crisis'];
    
    final words = text.toLowerCase().split(RegExp(r'[\s.,!?;:]+'));
    double score = 0.0;
    int emotionalWords = 0;
    
    for (final word in words) {
      if (word.length < 3) continue;
      
      if (positiveWords.any((pos) => word.contains(pos))) {
        score += 1.0;
        emotionalWords++;
      } else if (negativeWords.any((neg) => word.contains(neg))) {
        score -= 1.0;
        emotionalWords++;
      }
    }
    
    if (emotionalWords == 0) return 0.0;
    return (score / emotionalWords * 0.7).clamp(-1.0, 1.0); // Scale down for keywords
  }
  
  Color _getEmotionColor(double sentiment) {
    if (sentiment > 0.3) {
      return Colors.green;
    } else if (sentiment < -0.3) {
      return Colors.orange;
    } else {
      return AppColors.primary;
    }
  }
  
  String _getSentimentLabel(double sentiment) {
    if (sentiment > 0.3) {
      return 'Positive';
    } else if (sentiment < -0.3) {
      return 'Reflective';
    } else {
      return 'Neutral';
    }
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

// Custom painter for story length bubble chart
class StoryBubblePainter extends CustomPainter {
  final List<Map<String, dynamic>> bubblesData;
  
  StoryBubblePainter(this.bubblesData);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (bubblesData.isEmpty) return;
    
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Calculate bubble positions and sizes
    final bubbles = <Map<String, dynamic>>[];
    
    for (int i = 0; i < bubblesData.length; i++) {
      final data = bubblesData[i];
      final length = data['length'] as int;
      final year = data['year'] as int;
      final entry = data['entry'] as _TimelineEntry;
      
      // Calculate bubble size (min 15, max 60)
      final maxLength = bubblesData.map((d) => d['length'] as int).reduce(math.max);
      final minLength = bubblesData.map((d) => d['length'] as int).reduce(math.min);
      final normalizedSize = maxLength > minLength 
          ? (length - minLength) / (maxLength - minLength)
          : 0.5;
      final radius = 15.0 + (normalizedSize * 45.0);
      
      // Position bubbles in a more evenly distributed grid
      final cols = math.min((size.width / 80).floor(), 6); // Adjust based on canvas size
      final rows = (bubblesData.length / cols).ceil();
      final row = i ~/ cols;
      final col = i % cols;
      
      // Calculate grid cell dimensions
      final cellWidth = size.width / cols;
      final cellHeight = size.height / math.max(rows, 1);
      
      // Position within cell with some randomness
      final x = (col * cellWidth) + (cellWidth * 0.5) + 
                (math.Random(i).nextDouble() - 0.5) * (cellWidth * 0.2);
      final y = (row * cellHeight) + (cellHeight * 0.5) + 
                (math.Random(i + 1000).nextDouble() - 0.5) * (cellHeight * 0.2);
      
      // Make sure bubble fits in canvas with padding
      final padding = math.max(radius, 15.0);
      final clampedX = x.clamp(padding, size.width - padding);
      final clampedY = y.clamp(padding, size.height - padding);
      
      bubbles.add({
        'x': clampedX,
        'y': clampedY,
        'radius': radius,
        'year': year,
        'length': length,
        'entry': entry,
      });
    }
    
    // Draw bubbles
    for (final bubble in bubbles) {
      final x = bubble['x'] as double;
      final y = bubble['y'] as double;
      final radius = bubble['radius'] as double;
      final year = bubble['year'] as int;
      final length = bubble['length'] as int;
      
      // Get color for year
      final color = _getYearColor(year);
      
      // Draw filled bubble
      paint.color = color.withOpacity(0.7);
      canvas.drawCircle(Offset(x, y), radius, paint);
      
      // Draw border
      borderPaint.color = color;
      canvas.drawCircle(Offset(x, y), radius, borderPaint);
      
      // Draw year label
      final textPainter = TextPainter(
        text: TextSpan(
          text: year.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: math.min(radius / 3, 12),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      final textX = x - textPainter.width / 2;
      final textY = y - textPainter.height / 2;
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }
  
  Color _getYearColor(int year) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[year.hashCode % colors.length];
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

