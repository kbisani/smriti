import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

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
              final summary = meta['summary'] ?? '';
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
    return byYear;
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
                        final sortedYears = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
                        return ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Text(birthYear, style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 16)),
                            ),
                            Card(
                              color: AppColors.card,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Born in $birthPlace', style: AppTextStyles.body),
                              ),
                            ),
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
