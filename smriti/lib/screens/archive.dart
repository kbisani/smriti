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
  final TextEditingController _searchController = TextEditingController();
  late final QdrantProfileService _profileService;

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
    // Group entries by date only
    final Map<String, List<_ArchiveEntry>> groupedByDate = {};
    final filteredEntries = _entries.where((entry) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
        entry.displayPrompt.toLowerCase().contains(q) ||
        entry.transcript.toLowerCase().contains(q);
    }).toList();
    for (final entry in filteredEntries) {
      groupedByDate.putIfAbsent(entry.date, () => []).add(entry);
    }
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Archive', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by prompt or transcript...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: filteredEntries.isEmpty
                      ? Center(child: Text('No archived recordings found.', style: AppTextStyles.subhead))
                      : ListView(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          children: [
                            for (final date in sortedDates) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Text(
                                  date,
                                  style: AppTextStyles.label.copyWith(fontSize: 15, color: AppColors.primary),
                                ),
                              ),
                              for (final entry in groupedByDate[date]!)
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(color: AppColors.border, width: 1),
                                  ),
                                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                    title: Text(entry.displayPrompt, style: AppTextStyles.subhead),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.play_circle_fill, color: AppColors.primary, size: 32),
                                          tooltip: 'Play Audio',
                                          onPressed: () async {
                                            final player = AudioPlayer();
                                            await player.play(DeviceFileSource(entry.audioPath));
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.article_outlined, color: AppColors.textSecondary),
                                          tooltip: 'View Transcript',
                                          onPressed: () => _showTranscript(context, entry.displayPrompt, entry.transcript),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text('Delete Entry', style: AppTextStyles.subhead),
                                                content: Text('Delete this recording and transcript? This cannot be undone.', style: AppTextStyles.body),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(false),
                                                    child: Text('Cancel', style: AppTextStyles.label),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(true),
                                                    child: Text('Delete', style: AppTextStyles.label.copyWith(color: Colors.redAccent)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await _deleteEntry(entry);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ]
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final memory = await _profileService.getProfileMemory(widget.profileId);
          print('Profile memory for ${widget.profileId}:');
          print(memory.toJsonString());
        },
        child: Icon(Icons.bug_report),
        tooltip: 'Print memory.json to console',
      ),
    );
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