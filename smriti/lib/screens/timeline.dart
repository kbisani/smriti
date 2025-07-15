import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class _MosaicStory {
  final String summary;
  final int? year;
  final List<String> categories;
  final String? personalizedSummary;
  _MosaicStory({required this.summary, this.year, required this.categories, this.personalizedSummary});
}

class _TimelineEntry {
  final int year;
  final String summary;
  _TimelineEntry({required this.year, required this.summary});
}

class TimelinePage extends StatefulWidget {
  final SubUserProfile profile;
  const TimelinePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _predefinedCategories = [
    'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
  ];

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

  Future<Map<int, List<_TimelineEntry>>> _loadTimelineEntries() async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory('${appDir.path}/archive/profile_${widget.profile.id}');
    Map<int, List<_TimelineEntry>> byYear = {};
    if (await archiveRoot.exists()) {
      final dateDirs = archiveRoot.listSync().whereType<Directory>();
      for (final dateDir in dateDirs) {
        final recordingDirs = dateDir.listSync().whereType<Directory>();
        for (final recDir in recordingDirs) {
          final metaFile = File('${recDir.path}/meta.json');
          if (await metaFile.exists()) {
            try {
              final meta = jsonDecode(await metaFile.readAsString());
              final year = meta['year'];
              final summary = meta['personalized_summary'] ?? meta['summary'] ?? '';
              if (year != null && summary.isNotEmpty) {
                final y = int.tryParse(year.toString());
                if (y != null) {
                  byYear.putIfAbsent(y, () => []).add(_TimelineEntry(year: y, summary: summary));
                }
              }
            } catch (_) {}
          }
        }
      }
    }
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
  }

  Future<Map<String, List<_MosaicStory>>> _loadMosaicStories() async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory('${appDir.path}/archive/profile_${widget.profile.id}');
    Map<String, List<_MosaicStory>> byCategory = { for (var c in _predefinedCategories) c: [] };
    if (await archiveRoot.exists()) {
      final dateDirs = archiveRoot.listSync().whereType<Directory>();
      for (final dateDir in dateDirs) {
        final recordingDirs = dateDir.listSync().whereType<Directory>();
        for (final recDir in recordingDirs) {
          final metaFile = File('${recDir.path}/meta.json');
          if (await metaFile.exists()) {
            try {
              final meta = jsonDecode(await metaFile.readAsString());
              final summary = meta['personalized_summary'] ?? meta['summary'] ?? '';
              final year = meta['year'];
              final categories = (meta['categories'] is List)
                ? (meta['categories'] as List<dynamic>).map((e) => e.toString()).toList()
                : (meta['categories'] is String ? [meta['categories']] : <String>[]);
              if (summary.isNotEmpty && categories.isNotEmpty) {
                final story = _MosaicStory(
                  summary: summary,
                  year: year != null ? int.tryParse(year.toString()) : null,
                  categories: categories.cast<String>(),
                  personalizedSummary: meta['personalized_summary'],
                );
                for (final cat in categories) {
                  if (byCategory.containsKey(cat)) {
                    byCategory[cat]!.add(story);
                  }
                }
              }
            } catch (_) {}
          }
        }
      }
    }
    return byCategory;
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
                                Card(
                                  color: AppColors.card,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(entry.summary, style: AppTextStyles.body),
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
                                    builder: (_) => CategoryStoriesPage(category: cat, stories: stories),
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
  const CategoryStoriesPage({required this.category, required this.stories, Key? key}) : super(key: key);

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
                  return Card(
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: AppColors.border.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (story.year != null)
                            Text(story.year.toString(), style: AppTextStyles.label.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              story.summary,
                              style: AppTextStyles.body,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
