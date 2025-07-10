import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class ArchivePage extends StatefulWidget {
  final String profileId;
  const ArchivePage({required this.profileId, Key? key}) : super(key: key);
  @override
  _ArchivePageState createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<_ArchiveEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory('${appDir.path}/archive/profile_${widget.profileId}');
    List<_ArchiveEntry> entries = [];
    if (await archiveRoot.exists()) {
      final dateDirs = archiveRoot.listSync().whereType<Directory>();
      for (final dateDir in dateDirs) {
        final promptDirs = dateDir.listSync().whereType<Directory>();
        for (final promptDir in promptDirs) {
          final audioFile = File('${promptDir.path}/audio.aac');
          final transcriptFile = File('${promptDir.path}/transcript.txt');
          if (await audioFile.exists() && await transcriptFile.exists()) {
            final transcript = await transcriptFile.readAsString();
            entries.add(_ArchiveEntry(
              date: dateDir.path.split('/').last,
              prompt: promptDir.path.split('/').last.replaceAll('-', ' '),
              audioPath: audioFile.path,
              transcript: transcript,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Archive')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Text('No archived recordings yet.'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, idx) {
                    final entry = _entries[idx];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(entry.prompt),
                        subtitle: Text(entry.date),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_arrow),
                              onPressed: () async {
                                final player = AudioPlayer();
                                await player.play(DeviceFileSource(entry.audioPath));
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.article),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Transcript'),
                                    content: SingleChildScrollView(child: Text(entry.transcript)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ArchiveEntry {
  final String date;
  final String prompt;
  final String audioPath;
  final String transcript;
  _ArchiveEntry({required this.date, required this.prompt, required this.audioPath, required this.transcript});
}
