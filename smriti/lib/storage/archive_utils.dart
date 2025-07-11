import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/profile_memory.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

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
Future<String> saveToArchive({
  required File audioFile,
  required String transcript,
  required String prompt,
  required DateTime date,
  required String profileId,
  Map<String, dynamic>? metadata,
  String? archiveDirPath,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  Directory archiveDir;
  if (archiveDirPath != null) {
    archiveDir = Directory(archiveDirPath);
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
  } else {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final promptSlug = slugify(prompt);
    final timestamp = DateFormat('HHmmss').format(date) + '_' + date.millisecondsSinceEpoch.toString();
    archiveDir = Directory('${appDir.path}/archive/profile_$profileId/$dateStr/${timestamp}_$promptSlug');
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
  }

  // Add uuid to metadata if not present
  final uuid = Uuid().v4();
  if (metadata != null && metadata['uuid'] == null) {
    metadata['uuid'] = uuid;
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

  return archiveDir.path;
}

Future<File> _getMemoryFile(String profileId) async {
  final appDir = await getApplicationDocumentsDirectory();
  final memoryFile = File('${appDir.path}/archive/profile_$profileId/memory.json');
  return memoryFile;
}

Future<ProfileMemory> readProfileMemory(String profileId) async {
  final file = await _getMemoryFile(profileId);
  if (await file.exists()) {
    final jsonStr = await file.readAsString();
    return ProfileMemory.fromJsonString(jsonStr);
  } else {
    return ProfileMemory();
  }
}

Future<void> writeProfileMemory(String profileId, ProfileMemory memory) async {
  final file = await _getMemoryFile(profileId);
  await file.writeAsString(memory.toJsonString());
}

Future<ProfileMemory?> extractFactsWithOpenAI({
  required String transcript,
  required ProfileMemory currentMemory,
}) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final endpoint = 'https://api.openai.com/v1/chat/completions';
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final systemPrompt =
      'Given the following transcript and the current memory (as JSON), extract any new facts about the person (events, relationships, places, etc.) that are NOT already in memory. Respond ONLY in minified JSON with keys: name, birthYear, birthPlace, events (list), relationships (list). If no new facts, return an empty JSON object.';
  final userPrompt = 'Transcript: $transcript\nCurrent memory: ${currentMemory.toJsonString()}';
  final body = jsonEncode({
    'model': 'gpt-3.5-turbo',
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ],
    'max_tokens': 256,
    'temperature': 0.3,
  });
  try {
    final response = await http.post(Uri.parse(endpoint), headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      if (content.trim().isNotEmpty) {
        final jsonMap = jsonDecode(content);
        return ProfileMemory.fromJson(jsonMap);
      }
    }
  } catch (e) {
    // ignore
  }
  return null;
}

Future<void> updateProfileMemoryWithStory({
  required String profileId,
  required Map<String, dynamic> meta,
  required String transcript,
}) async {
  // Read current memory
  final memory = await readProfileMemory(profileId);

  // Use OpenAI to extract new facts from transcript/meta and merge
  final extracted = await extractFactsWithOpenAI(transcript: transcript, currentMemory: memory);
  if (extracted != null) {
    // Add uuid to each new event if not present
    final uuid = meta['uuid'] ?? Uuid().v4();
    for (final event in extracted.events) {
      if (event['uuid'] == null) {
        event['uuid'] = uuid;
      }
    }
    memory.merge(extracted);
  }

  // Also add the event from meta if year/summary exist (fallback)
  final year = meta['year'];
  final summary = meta['summary'];
  final uuid = meta['uuid'] ?? Uuid().v4();
  if (year != null && summary != null) {
    final y = int.tryParse(year.toString());
    if (y != null) {
      // Only add if not already present
      if (!memory.events.any((e) => e['uuid'] == uuid)) {
        memory.events.add({'year': y, 'event': summary, 'uuid': uuid});
      }
    }
  }
  // Save updated memory
  await writeProfileMemory(profileId, memory);
}

Future<void> removeEventFromMemoryByUuid(String profileId, String uuid) async {
  final memory = await readProfileMemory(profileId);
  memory.events.removeWhere((e) => e['uuid'] == uuid);
  await writeProfileMemory(profileId, memory);
}

Future<String> generatePersonalizedEventSummary({
  required Map<String, dynamic> eventMeta,
  required ProfileMemory memory,
}) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final endpoint = 'https://api.openai.com/v1/chat/completions';
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final systemPrompt =
      """
Given the following event metadata and the person's memory (as JSON), write a 1-2 sentence summary of the event that is personalized and context-aware. 
- Use the person's actual name and relationships from the memory if available, instead of generic terms like 'the speaker' or placeholders like [spouse's name] or [partner's name].
- Never use variables or placeholders in the summary; use real names if available, or omit them if not.
- Do not invent facts.
Respond with only the summary text.
""";
  final userPrompt = 'Event meta: ${jsonEncode(eventMeta)}\nProfile memory: ${memory.toJsonString()}';
  final body = jsonEncode({
    'model': 'gpt-3.5-turbo',
    'messages': [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ],
    'max_tokens': 128,
    'temperature': 0.3,
  });
  try {
    final response = await http.post(Uri.parse(endpoint), headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    }
  } catch (e) {
    // ignore
  }
  // Fallback: use the summary from meta
  return eventMeta['summary'] ?? '';
} 