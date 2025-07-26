// archive_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme.dart';
import 'package:path/path.dart' as p;
import '../storage/qdrant_profile_service.dart';
import 'dart:convert'; // Added for jsonDecode

class ArchivePage extends StatefulWidget {
  final String profileId;
  const ArchivePage({required this.profileId, Key? key}) : super(key: key);
  @override
  _ArchivePageState createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<_ArchiveEntry> _entries = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedDateRange;
  bool _isGridView = false;
  final TextEditingController _searchController = TextEditingController();
  late final QdrantProfileService _profileService;
  
  static const List<String> _categories = [
    'love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth'
  ];

  @override
  void initState() {
    super.initState();
    _profileService = QdrantProfileService();
    _loadArchive();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArchive() async {
    try {
      final recordings = await _profileService.getAllRecordings(widget.profileId);
      List<_ArchiveEntry> entries = [];
      
      for (final recording in recordings) {
        final dateStr = recording['date'] ?? '';
        final prompt = recording['prompt'] ?? '';
        final audioPath = recording['audio_path'];
        final transcript = recording['transcript'] ?? '';
        final uuid = recording['uuid'] ?? '';
        
        print('DEBUG Archive: Recording data: prompt="$prompt", transcript length=${transcript.length}, uuid=$uuid');
        
        if (transcript.isNotEmpty) {
          // Format the date for display
          final date = DateTime.tryParse(dateStr);
          final displayDate = date != null 
            ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
            : dateStr;
          
          final cleanedPrompt = _prettifyPrompt(prompt);
          final promptKey = cleanedPrompt.toLowerCase();

          entries.add(_ArchiveEntry(
            date: displayDate,
            promptKey: promptKey,
            displayPrompt: cleanedPrompt,
            audioPath: audioPath ?? '',
            transcript: transcript,
            folderName: uuid, // Use UUID as folder identifier
            uuid: uuid,
            summary: recording['summary'],
            personalizedSummary: recording['personalized_summary'],
            categories: List<String>.from(recording['categories'] ?? []),
          ));
        }
      }
      
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      print('Error loading archive: $e');
      setState(() {
        _entries = [];
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(_ArchiveEntry entry) async {
    try {
      // Delete from Qdrant using UUID
      if (entry.uuid.isNotEmpty) {
        // Try to delete recording first (this should always exist)
        try {
          await _profileService.deleteRecording(entry.uuid);
          print('Deleted recording: ${entry.uuid}');
        } catch (e) {
          print('Error deleting recording ${entry.uuid}: $e');
        }
        
        // Try to delete event (this might not exist for continuations)
        try {
          await _profileService.deleteEvent(entry.uuid);
          print('Deleted event: ${entry.uuid}');
        } catch (e) {
          print('Error deleting event ${entry.uuid} (might not exist): $e');
        }
      }
      
      // Also delete local audio file if it exists
      if (entry.audioPath.isNotEmpty) {
        final audioFile = File(entry.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
          print('Deleted audio file: ${entry.audioPath}');
        }
      }
      
      await _loadArchive();
    } catch (e) {
      print('Error deleting entry: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recording: $e')),
      );
    }
  }

  String _prettifyPrompt(String prompt) {
    return prompt.split(' ').map((word) {
      if (word.trim().isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
  
  List<_ArchiveEntry> _getFilteredEntries() {
    return _entries.where((entry) {
      // Search query filter
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          entry.displayPrompt.toLowerCase().contains(q) ||
          entry.transcript.toLowerCase().contains(q) ||
          (entry.summary?.toLowerCase().contains(q) ?? false) ||
          (entry.personalizedSummary?.toLowerCase().contains(q) ?? false);
      
      // Category filter
      final matchesCategory = _selectedCategory == null ||
          entry.categories.contains(_selectedCategory);
      
      // Date range filter (simplified - could be enhanced)
      final matchesDateRange = _selectedDateRange == null ||
          _matchesDateRange(entry.date, _selectedDateRange!);
      
      return matchesSearch && matchesCategory && matchesDateRange;
    }).toList();
  }
  
  bool _matchesDateRange(String entryDate, String range) {
    final entryDateTime = DateTime.tryParse(entryDate);
    if (entryDateTime == null) return true;
    
    final now = DateTime.now();
    switch (range) {
      case 'This Week':
        final weekAgo = now.subtract(Duration(days: 7));
        return entryDateTime.isAfter(weekAgo);
      case 'This Month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return entryDateTime.isAfter(monthAgo);
      case 'This Year':
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        return entryDateTime.isAfter(yearAgo);
      default:
        return true;
    }
  }
  
  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }
  
  String _getDisplaySummary(_ArchiveEntry entry) {
    // Prioritize personalized summary, then regular summary, then transcript excerpt
    if (entry.personalizedSummary != null && entry.personalizedSummary!.isNotEmpty) {
      return entry.personalizedSummary!;
    } else if (entry.summary != null && entry.summary!.isNotEmpty) {
      return entry.summary!;
    } else {
      // Fallback to transcript excerpt with cleaner formatting
      final transcript = entry.transcript;
      if (transcript.isEmpty) return 'No summary available';
      
      // Get first 150 characters and try to end at a sentence boundary
      final truncated = transcript.substring(0, transcript.length.clamp(0, 150));
      final lastPeriod = truncated.lastIndexOf('.');
      final lastExclamation = truncated.lastIndexOf('!');
      final lastQuestion = truncated.lastIndexOf('?');
      
      final lastSentenceEnd = [lastPeriod, lastExclamation, lastQuestion]
          .where((index) => index > 50) // Only consider if we have at least 50 chars
          .fold(-1, (max, current) => current > max ? current : max);
      
      if (lastSentenceEnd > 0) {
        return truncated.substring(0, lastSentenceEnd + 1);
      } else {
        return truncated + '...';
      }
    }
  }

  void _showTranscript(BuildContext context, String prompt, String transcript) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transcript', style: AppTextStyles.subhead),
            SizedBox(height: 8),
            Text(prompt, style: AppTextStyles.label),
            SizedBox(height: 16),
            SingleChildScrollView(
              child: Text(transcript, style: AppTextStyles.body.copyWith(fontSize: 16)),
            ),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Close', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _getFilteredEntries();
    
    // Group entries by date
    final Map<String, List<_ArchiveEntry>> groupedByDate = {};
    for (final entry in filteredEntries) {
      groupedByDate.putIfAbsent(entry.date, () => []).add(entry);
    }
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and view toggle
            _buildHeader(),
            
            // Search and filters
            _buildSearchAndFilters(),
            
            // Content
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : filteredEntries.isEmpty
                      ? _buildEmptyState()
                      : _isGridView
                          ? _buildGridView(filteredEntries)
                          : _buildListView(groupedByDate, sortedDates),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Archive',
              style: AppTextStyles.headline.copyWith(fontSize: 28),
            ),
          ),
          // View toggle
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
                    Icons.view_list,
                    color: !_isGridView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isGridView = false),
                  tooltip: 'List View',
                ),
                IconButton(
                  icon: Icon(
                    Icons.grid_view,
                    color: _isGridView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isGridView = true),
                  tooltip: 'Grid View',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchAndFilters() {
    final hasActiveFilters = _selectedCategory != null || _selectedDateRange != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search memories, transcripts, summaries...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: hasActiveFilters
                  ? IconButton(
                      icon: Icon(Icons.filter_list, color: AppColors.primary),
                      onPressed: _clearFilters,
                      tooltip: 'Clear filters',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          
          const SizedBox(height: 16),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Category filter
                ChoiceChip(
                  label: Text(_selectedCategory ?? 'All Categories'),
                  selected: _selectedCategory != null,
                  onSelected: (selected) {
                    if (selected) {
                      _showCategoryPicker();
                    } else {
                      setState(() => _selectedCategory = null);
                    }
                  },
                ),
                
                const SizedBox(width: 12),
                
                // Date range filter
                ChoiceChip(
                  label: Text(_selectedDateRange ?? 'All Time'),
                  selected: _selectedDateRange != null,
                  onSelected: (selected) {
                    if (selected) {
                      _showDateRangePicker();
                    } else {
                      setState(() => _selectedDateRange = null);
                    }
                  },
                ),
                
                const SizedBox(width: 12),
                
                // Results count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_getFilteredEntries().length} memories',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No memories found',
            style: AppTextStyles.subhead,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null || _selectedDateRange != null
                ? 'Try adjusting your search or filters'
                : 'Your recorded memories will appear here',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildGridView(List<_ArchiveEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75, // Slightly taller cards for better summary display
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildGridCard(entries[index]),
    );
  }
  
  Widget _buildListView(Map<String, List<_ArchiveEntry>> groupedByDate, List<String> sortedDates) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final entries = groupedByDate[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _formatDateHeader(date),
                style: AppTextStyles.label.copyWith(
                  fontSize: 16,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Entries for this date
            ...entries.map((entry) => _buildListCard(entry)),
          ],
        );
      },
    );
  }
  
  String _formatDateHeader(String date) {
    final dateTime = DateTime.tryParse(date);
    if (dateTime == null) return date;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final entryDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }
  
  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Category',
              style: AppTextStyles.subhead,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((category) {
                return ChoiceChip(
                  label: Text(category.substring(0, 1).toUpperCase() + category.substring(1)),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _showDateRangePicker() {
    final ranges = ['This Week', 'This Month', 'This Year'];
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Time',
              style: AppTextStyles.subhead,
            ),
            const SizedBox(height: 16),
            ...ranges.map((range) {
              return ListTile(
                title: Text(range),
                selected: _selectedDateRange == range,
                onTap: () {
                  setState(() {
                    _selectedDateRange = _selectedDateRange == range ? null : range;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildListCard(_ArchiveEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
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
                AppColors.card.withOpacity(0.9),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with prompt and audio button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.displayPrompt,
                      style: AppTextStyles.subhead.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_circle_fill, 
                              color: AppColors.primary, size: 32),
                    onPressed: () async {
                      final player = AudioPlayer();
                      await player.play(DeviceFileSource(entry.audioPath));
                    },
                    tooltip: 'Play Audio',
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Summary
              if (entry.personalizedSummary != null || entry.summary != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Text(
                    entry.personalizedSummary ?? entry.summary ?? '',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Categories and actions row
              Row(
                children: [
                  // Categories
                  if (entry.categories.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: entry.categories.take(3).map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.article_outlined, 
                                  color: AppColors.textSecondary),
                        onPressed: () => _showTranscript(
                          context, entry.displayPrompt, entry.transcript),
                        tooltip: 'View Transcript',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, 
                                  color: Colors.redAccent),
                        onPressed: () => _confirmDelete(entry),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGridCard(_ArchiveEntry entry) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.border.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.card,
              AppColors.card.withOpacity(0.9),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with audio button
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.displayPrompt,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.play_circle_fill, 
                            color: AppColors.primary, size: 24),
                  onPressed: () async {
                    final player = AudioPlayer();
                    await player.play(DeviceFileSource(entry.audioPath));
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Summary
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary type indicator (only show for AI summaries)
                    if (entry.personalizedSummary != null && entry.personalizedSummary!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AI Summary',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    
                    // Summary text
                    Expanded(
                      child: Text(
                        _getDisplaySummary(entry),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: entry.personalizedSummary != null ? 4 : 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Categories
            if (entry.categories.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: entry.categories.take(2).map((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 8),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.article_outlined, 
                            color: AppColors.textSecondary, size: 20),
                  onPressed: () => _showTranscript(
                    context, entry.displayPrompt, entry.transcript),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline, 
                            color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDelete(entry),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _confirmDelete(_ArchiveEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Memory', style: AppTextStyles.subhead),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete this recording and transcript? This cannot be undone.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.2)),
              ),
              child: Text(
                entry.displayPrompt,
                style: AppTextStyles.label.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
            ),
            child: Text(
              'Delete',
              style: AppTextStyles.label.copyWith(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteEntry(entry);
    }
  }
}

class _ArchiveEntry {
  final String date;
  final String promptKey;
  final String displayPrompt;
  final String audioPath;
  final String transcript;
  final String folderName;
  final String uuid;
  final String? summary;
  final String? personalizedSummary;
  final List<String> categories;

  _ArchiveEntry({
    required this.date,
    required this.promptKey,
    required this.displayPrompt,
    required this.audioPath,
    required this.transcript,
    required this.folderName,
    required this.uuid,
    this.summary,
    this.personalizedSummary,
    this.categories = const [],
  });
}