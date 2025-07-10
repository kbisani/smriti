import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

/// Slugifies a string for use as a folder name (e.g., 'Wisdom About Failure' -> 'wisdom-about-failure')
String slugify(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+\u0000'), '')
      .substring(0, input.length > 32 ? 32 : input.length)
      .replaceAll(RegExp(r'-+\u0000'), '');
}

/// Saves audio, transcript, and metadata to the archive folder structure for a specific profile
Future<void> saveToArchive({
  required File audioFile,
  required String transcript,
  required String prompt,
  required DateTime date,
  required String profileId,
  Map<String, dynamic>? metadata,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  final promptSlug = slugify(prompt);
  final timestamp = DateFormat('HHmmss').format(date) + '_' + date.millisecondsSinceEpoch.toString();
  final archiveDir = Directory('${appDir.path}/archive/profile_$profileId/$dateStr/${timestamp}_$promptSlug');
  if (!await archiveDir.exists()) {
    await archiveDir.create(recursive: true);
  }

  // Save audio (copy to archive as audio.aac)
  final audioArchivePath = '${archiveDir.path}/audio.aac';
  await audioFile.copy(audioArchivePath);

  // Save transcript
  final transcriptFile = File('${archiveDir.path}/transcript.txt');
  await transcriptFile.writeAsString(transcript);

  // Save metadata if provided
  if (metadata != null) {
    final metaFile = File('${archiveDir.path}/meta.json');
    await metaFile.writeAsString(jsonEncode(metadata));
  }
} 