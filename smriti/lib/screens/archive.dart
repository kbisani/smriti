// archive_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme.dart';
import 'package:path/path.dart' as p;
import '../storage/archive_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArchive() async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory('${appDir.path}/archive/profile_${widget.profileId}');
    List<_ArchiveEntry> entries = [];
    if (await archiveRoot.exists()) {
      final dateDirs = archiveRoot.listSync().whereType<Directory>();
      for (final dateDir in dateDirs) {
        final recordingDirs = dateDir.listSync().whereType<Directory>();
        for (final recDir in recordingDirs) {
          final audioFile = File('${recDir.path}/audio.aac');
          final transcriptFile = File('${recDir.path}/transcript.txt');
          if (await audioFile.exists() && await transcriptFile.exists()) {
            final transcript = await transcriptFile.readAsString();
            final folderName = p.basename(recDir.path);
            final promptPart = folderName.contains('_')
                ? folderName.substring(folderName.indexOf('_') + 1)
                : folderName;
            final cleanedPrompt = promptPart
                .replaceAll(RegExp(r'[_-]'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim()
                .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

            final promptKey = cleanedPrompt.toLowerCase();

            entries.add(_ArchiveEntry(
              date: p.basename(dateDir.path),
              promptKey: promptKey,
              displayPrompt: _prettifyPrompt(cleanedPrompt),
              audioPath: audioFile.path,
              transcript: transcript,
              folderName: folderName,
            ));
          }
        }
      }
    }
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(_ArchiveEntry entry) async {
    final appDir = await getApplicationDocumentsDirectory();
    final folderPath = p.join(
      appDir.path,
      'archive',
      'profile_${widget.profileId}',
      entry.date,
      entry.folderName,
    );
    // Read uuid from meta.json if it exists
    final metaFile = File(p.join(folderPath, 'meta.json'));
    String? uuid;
    if (await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString());
        uuid = meta['uuid'] as String?;
      } catch (_) {}
    }
    final dir = Directory(folderPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    // Remove event from memory.json if uuid found
    if (uuid != null) {
      await removeEventFromMemoryByUuid(widget.profileId, uuid);
    }
    await _loadArchive();
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
          final memory = await readProfileMemory(widget.profileId);
          print('memory.json for profile ${widget.profileId}:');
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

  _ArchiveEntry({
    required this.date,
    required this.promptKey,
    required this.displayPrompt,
    required this.audioPath,
    required this.transcript,
    required this.folderName,
  });
}