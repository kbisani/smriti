
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/profile_memory.dart';
import '../models/sub_user_profile.dart';
import 'qdrant_service.dart';
import 'embedding_service.dart';

/// Service that manages profile data using Qdrant instead of JSON files
class QdrantProfileService {
  late final QdrantService _qdrant;
  
  QdrantProfileService() {
    final baseUrl = dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333';
    final apiKey = dotenv.env['QDRANT_API_KEY'] ?? '';
    _qdrant = QdrantService(baseUrl: baseUrl, apiKey: apiKey);
  }

  /// Initialize the service and create collections
  Future<void> initialize() async {
    print('Initializing Qdrant collections...');
    try {
      await _qdrant.initializeCollections();
      print('Qdrant collections initialized successfully');
    } catch (e) {
      print('Error initializing Qdrant collections: $e');
      rethrow;
    }
  }

  /// Store profile in Qdrant
  Future<void> storeProfile(SubUserProfile profile) async {
    print('Storing profile: ${profile.name} (ID: ${profile.id})');
    try {
      final embedding = await EmbeddingService.generateProfileEmbedding(
        name: profile.name,
        bio: profile.bio,
        birthPlace: profile.birthPlace,
        tags: profile.tags,
      );
      print('Generated embedding for profile: ${embedding.length} dimensions');
      
      await _qdrant.upsertProfile(
        profile: profile,
        embedding: embedding,
      );
      print('Profile stored successfully in Qdrant');
    } catch (e) {
      print('Error storing profile: $e');
      rethrow;
    }
  }

  /// Store profile memory in Qdrant
  Future<void> storeProfileMemory(String profileId, ProfileMemory memory) async {
    final embedding = await EmbeddingService.generateMemoryEmbedding(
      name: memory.name,
      birthPlace: memory.birthPlace,
      events: memory.events,
      relationships: memory.relationships,
    );

    await _qdrant.upsertProfileMemory(
      profileId: profileId,
      memory: memory,
      embedding: embedding,
    );
  }

  /// Store individual events in Qdrant
  Future<void> storeEvents(String profileId, List<Map<String, dynamic>> events) async {
    for (final event in events) {
      final eventId = event['uuid'] ?? const Uuid().v4();
      final embedding = await EmbeddingService.generateEventEmbedding(
        event: event['event']?.toString() ?? '',
        year: event['year'],
      );

      await _qdrant.upsertEvent(
        profileId: profileId,
        eventId: eventId,
        eventData: event,
        embedding: embedding,
      );
    }
  }

  /// Store recording metadata in Qdrant
  Future<void> storeRecording({
    required String profileId,
    required String recordingId,
    required String transcript,
    required Map<String, dynamic> metadata,
  }) async {
    final embedding = await EmbeddingService.generateRecordingEmbedding(
      transcript: transcript,
      summary: metadata['summary'],
      personalizedSummary: metadata['personalized_summary'],
      categories: metadata['categories'] is List 
        ? List<String>.from(metadata['categories']) 
        : null,
    );

    final fullMetadata = {
      ...metadata,
      'transcript': transcript,
    };

    await _qdrant.upsertRecording(
      profileId: profileId,
      recordingId: recordingId,
      metadata: fullMetadata,
      embedding: embedding,
    );
  }

  /// Get profile memory from Qdrant
  Future<ProfileMemory> getProfileMemory(String profileId) async {
    final memoryData = await _qdrant.getProfileMemory(profileId);
    
    if (memoryData == null) {
      return ProfileMemory();
    }

    final payload = memoryData['payload'] as Map<String, dynamic>;
    
    // Get events separately
    final events = await _qdrant.getEventsByProfile(profileId);
    final eventsList = events.map((e) {
      final payload = e['payload'] as Map<String, dynamic>;
      return {
        'year': payload['year'],
        'event': payload['event'],
        'uuid': payload['uuid'],
      };
    }).toList();

    return ProfileMemory(
      name: payload['name'],
      birthYear: payload['birth_year'],
      birthPlace: payload['birth_place'],
      events: eventsList,
      relationships: [], // TODO: Implement relationships
    );
  }

  /// Update profile memory with new story data
  Future<void> updateProfileMemoryWithStory({
    required String profileId,
    required Map<String, dynamic> metadata,
    required String transcript,
  }) async {
    // Get current memory first
    final currentMemory = await getProfileMemory(profileId);

    // Generate personalized summary if metadata exists
    String? personalizedSummary;
    if (metadata.isNotEmpty) {
      personalizedSummary = await _generatePersonalizedEventSummary(
        eventMeta: metadata,
        memory: currentMemory,
      );
      metadata['personalized_summary'] = personalizedSummary;
    }

    // Store the recording with updated metadata
    final recordingId = metadata['uuid'] ?? const Uuid().v4();
    await storeRecording(
      profileId: profileId,
      recordingId: recordingId,
      transcript: transcript,
      metadata: metadata,
    );

    // Extract new facts using AI (similar to existing logic)
    final extractedMemory = await _extractFactsWithOpenAI(
      transcript: transcript,
      currentMemory: currentMemory,
    );

    if (extractedMemory != null) {
      // Add uuid to each new event if not present
      final uuid = metadata['uuid'] ?? const Uuid().v4();
      for (final event in extractedMemory.events) {
        if (event['uuid'] == null) {
          event['uuid'] = uuid;
        }
      }
      
      // Store new events
      await storeEvents(profileId, extractedMemory.events);
      
      // Update memory
      currentMemory.merge(extractedMemory);
      await storeProfileMemory(profileId, currentMemory);
    }

    // Add event from metadata if year/summary exist (fallback)
    final year = metadata['year'];
    final summary = metadata['summary'];
    final uuid = metadata['uuid'] ?? const Uuid().v4();
    
    if (year != null && summary != null) {
      final y = int.tryParse(year.toString());
      if (y != null) {
        final eventData = {
          'year': y,
          'event': summary,
          'uuid': uuid,
        };
        
        // Check if event already exists (with error handling)
        List<Map<String, dynamic>> existingEvents = [];
        try {
          existingEvents = await _qdrant.getEventsByProfile(profileId);
        } catch (e) {
          print('Warning: Could not check existing events: $e');
          // Continue anyway - better to have duplicate than fail
        }
        
        final eventExists = existingEvents.any((e) => 
          e['payload']['uuid'] == uuid
        );
        
        if (!eventExists) {
          await storeEvents(profileId, [eventData]);
        }
      }
    }
  }

  /// Get timeline data for a profile (groups story continuations as sessions)
  Future<Map<int, List<Map<String, dynamic>>>> getTimelineData(String profileId) async {
    try {
      final recordings = await _qdrant.getRecordingsByProfile(profileId);
      print('DEBUG Timeline: Total recordings found: ${recordings.length}');
      final Map<int, List<Map<String, dynamic>>> byYear = {};
      final Map<String, Map<String, dynamic>> consolidatedStories = {};
      
      // First pass: collect all original stories
      final List<Map<String, dynamic>> continuations = [];
      
      for (final recording in recordings) {
        try {
          final payload = recording['payload'] as Map<String, dynamic>;
          final year = payload['year'];
          final summary = payload['personalized_summary'] ?? payload['summary'] ?? '';
          final uuid = payload['uuid'] ?? '';
          final isContinuation = payload['is_continuation'] == true;
          
          print('DEBUG Timeline: Processing recording - UUID: $uuid, isContinuation: $isContinuation, originalStoryUuid: ${payload['original_story_uuid']}, consolidatedSummary: ${payload['consolidated_summary'] != null ? 'EXISTS' : 'NULL'}');
          
          if (year != null && summary.isNotEmpty && uuid.isNotEmpty) {
            final y = int.tryParse(year.toString());
            if (y != null) {
              if (!isContinuation) {
                // This is an original story
                consolidatedStories[uuid] = {
                  'year': y,
                  'summary': summary,
                  'uuid': uuid,
                  'original_prompt': payload['prompt'] ?? '',
                  'transcript': payload['transcript'] ?? '',
                  'consolidated_summary': payload['consolidated_summary'], // Store pre-generated summary
                  'sessions': [
                    {
                      'uuid': uuid,
                      'transcript': payload['transcript'] ?? '',
                      'prompt': payload['prompt'] ?? '',
                      'date': payload['date'] ?? '',
                    }
                  ],
                  'session_count': 1,
                };
                print('DEBUG Timeline: ✅ Added original story - UUID: $uuid');
              } else {
                // Store continuation for second pass
                continuations.add(payload);
                print('DEBUG Timeline: 📝 Stored continuation $uuid for later processing (original: ${payload['original_story_uuid']})');
              }
            }
          }
        } catch (e) {
          print('Warning: Could not process recording: $e');
          // Continue with next recording
        }
      }
      
      print('DEBUG Timeline: Original stories: ${consolidatedStories.length}, Continuations to process: ${continuations.length}');
      print('DEBUG Timeline: Original story UUIDs: ${consolidatedStories.keys.toList()}');
      
      // Second pass: process all continuations
      for (final continuation in continuations) {
        try {
          final uuid = continuation['uuid'] ?? '';
          final originalStoryUuid = continuation['original_story_uuid'];
          final year = continuation['year'];
          final summary = continuation['personalized_summary'] ?? continuation['summary'] ?? '';
          
          print('DEBUG Timeline: Processing continuation $uuid for original story $originalStoryUuid');
          
          if (originalStoryUuid != null) {
            if (consolidatedStories.containsKey(originalStoryUuid)) {
              // Add continuation as session to original story
              final originalStory = consolidatedStories[originalStoryUuid]!;
              final sessions = List<Map<String, dynamic>>.from(originalStory['sessions'] ?? []);
              sessions.add({
                'uuid': uuid,
                'transcript': continuation['transcript'] ?? '',
                'prompt': continuation['continuation_prompt'] ?? continuation['prompt'] ?? '',
                'date': continuation['date'] ?? '',
              });
              
              // Update the story with the new session
              consolidatedStories[originalStoryUuid] = {
                ...originalStory,
                'sessions': sessions,
                'session_count': sessions.length,
                'consolidated_summary': originalStory['consolidated_summary'], // Preserve existing summary
              };
              print('DEBUG Timeline: ✅ Added continuation $uuid to story $originalStoryUuid - new session count: ${sessions.length}');
            } else {
              print('DEBUG Timeline: ❌ WARNING - Could not find original story $originalStoryUuid for continuation $uuid');
              print('DEBUG Timeline: Available original stories: ${consolidatedStories.keys.toList()}');
              
              // FALLBACK: Create a standalone story entry if original not found
              // This ensures continuations don't disappear from timeline
              final y = int.tryParse(year?.toString() ?? '');
              if (y != null && summary.isNotEmpty) {
                print('DEBUG Timeline: 🔄 Creating fallback story entry for orphaned continuation $uuid');
                consolidatedStories[uuid] = {
                  'year': y,
                  'summary': '$summary (continuation)',
                  'uuid': uuid,
                  'original_prompt': continuation['continuation_prompt'] ?? continuation['prompt'] ?? '',
                  'transcript': continuation['transcript'] ?? '',
                  'sessions': [
                    {
                      'uuid': uuid,
                      'transcript': continuation['transcript'] ?? '',
                      'prompt': continuation['continuation_prompt'] ?? continuation['prompt'] ?? '',
                      'date': continuation['date'] ?? '',
                    }
                  ],
                  'session_count': 1,
                  'is_orphaned_continuation': true,
                };
                print('DEBUG Timeline: ✅ Created fallback story entry for continuation $uuid');
              }
            }
          } else {
            print('DEBUG Timeline: ❌ Continuation $uuid has no original_story_uuid');
          }
        } catch (e) {
          print('Warning: Could not process continuation: $e');
        }
      }
      
      print('DEBUG Timeline: Final consolidated stories count: ${consolidatedStories.length}');
      
      // Third pass: organize consolidated stories by year for timeline
      for (final story in consolidatedStories.values) {
        final year = story['year'] as int;
        byYear.putIfAbsent(year, () => []).add(story);
      }

      return byYear;
    } catch (e) {
      print('Error loading timeline data: $e');
      return {};
    }
  }

  /// Get mosaic data for a profile grouped by categories (groups story continuations)
  Future<Map<String, List<Map<String, dynamic>>>> getMosaicData(String profileId) async {
    try {
      final recordings = await _qdrant.getRecordingsByProfile(profileId);
      print('DEBUG Mosaic: Total recordings found: ${recordings.length}');
      final Map<String, List<Map<String, dynamic>>> byCategory = {};
      final Map<String, Map<String, dynamic>> consolidatedStories = {};
      
      const predefinedCategories = [
        'love', 'family', 'career', 'wisdom', 'friends', 'education', 
        'health', 'adventure', 'loss', 'growth'
      ];
      
      for (final category in predefinedCategories) {
        byCategory[category] = [];
      }

      // First pass: collect all original stories
      final List<Map<String, dynamic>> continuations = [];
      
      for (final recording in recordings) {
        try {
          final payload = recording['payload'] as Map<String, dynamic>;
          final summary = payload['personalized_summary'] ?? payload['summary'] ?? '';
          final year = payload['year'];
          final categories = payload['categories'];
          final uuid = payload['uuid'] ?? '';
          final isContinuation = payload['is_continuation'] == true;
          
          print('DEBUG Mosaic: Processing recording - UUID: $uuid, isContinuation: $isContinuation');
          
          if (summary.isNotEmpty && categories is List && uuid.isNotEmpty) {
            if (!isContinuation) {
              // This is an original story
              consolidatedStories[uuid] = {
                'summary': summary,
                'year': year != null ? int.tryParse(year.toString()) : null,
                'categories': List<String>.from(categories),
                'personalizedSummary': payload['personalized_summary'],
                'uuid': uuid,
                'sessions': [
                  {
                    'uuid': uuid,
                    'transcript': payload['transcript'] ?? '',
                    'prompt': payload['prompt'] ?? '',
                    'date': payload['date'] ?? '',
                  }
                ],
                'session_count': 1,
              };
              print('DEBUG Mosaic: ✅ Added original story - UUID: $uuid');
            } else {
              // Store continuation for second pass
              continuations.add(payload);
              print('DEBUG Mosaic: 📝 Stored continuation $uuid for later processing');
            }
          }
        } catch (e) {
          print('Warning: Could not process recording for mosaic: $e');
          // Continue with next recording
        }
      }
      
      print('DEBUG Mosaic: Original stories: ${consolidatedStories.length}, Continuations to process: ${continuations.length}');
      
      // Second pass: process all continuations
      for (final continuation in continuations) {
        try {
          final uuid = continuation['uuid'] ?? '';
          final originalStoryUuid = continuation['original_story_uuid'];
          final summary = continuation['personalized_summary'] ?? continuation['summary'] ?? '';
          final categories = continuation['categories'];
          
          print('DEBUG Mosaic: Processing continuation $uuid for original story $originalStoryUuid');
          
          if (originalStoryUuid != null) {
            if (consolidatedStories.containsKey(originalStoryUuid)) {
              // Add continuation as session to original story
              final originalStory = consolidatedStories[originalStoryUuid]!;
              final sessions = List<Map<String, dynamic>>.from(originalStory['sessions'] ?? []);
              sessions.add({
                'uuid': uuid,
                'transcript': continuation['transcript'] ?? '',
                'prompt': continuation['continuation_prompt'] ?? continuation['prompt'] ?? '',
                'date': continuation['date'] ?? '',
              });
              
              // Update the story with the new session
              consolidatedStories[originalStoryUuid] = {
                ...originalStory,
                'sessions': sessions,
                'session_count': sessions.length,
              };
              print('DEBUG Mosaic: ✅ Added continuation $uuid to story $originalStoryUuid - new session count: ${sessions.length}');
            } else {
              print('DEBUG Mosaic: ❌ WARNING - Could not find original story $originalStoryUuid for continuation $uuid');
              
              // FALLBACK: Create a standalone story entry if original not found
              if (summary.isNotEmpty && categories is List) {
                print('DEBUG Mosaic: 🔄 Creating fallback story entry for orphaned continuation $uuid');
                consolidatedStories[uuid] = {
                  'summary': '$summary (continuation)',
                  'year': continuation['year'] != null ? int.tryParse(continuation['year'].toString()) : null,
                  'categories': List<String>.from(categories),
                  'personalizedSummary': continuation['personalized_summary'],
                  'uuid': uuid,
                  'sessions': [
                    {
                      'uuid': uuid,
                      'transcript': continuation['transcript'] ?? '',
                      'prompt': continuation['continuation_prompt'] ?? continuation['prompt'] ?? '',
                      'date': continuation['date'] ?? '',
                    }
                  ],
                  'session_count': 1,
                  'is_orphaned_continuation': true,
                };
                print('DEBUG Mosaic: ✅ Created fallback story entry for continuation $uuid');
              }
            }
          } else {
            print('DEBUG Mosaic: ❌ Continuation $uuid has no original_story_uuid');
          }
        } catch (e) {
          print('Warning: Could not process continuation for mosaic: $e');
        }
      }
      
      print('DEBUG Mosaic: Final consolidated stories count: ${consolidatedStories.length}');

      // Third pass: organize consolidated stories by category
      for (final story in consolidatedStories.values) {
        final categories = story['categories'] as List<String>;
        for (final category in categories) {
          if (byCategory.containsKey(category)) {
            byCategory[category]!.add(story);
          }
        }
      }

      return byCategory;
    } catch (e) {
      print('Error loading mosaic data: $e');
      return { for (final c in ['love', 'family', 'career', 'wisdom', 'friends', 'education', 'health', 'adventure', 'loss', 'growth']) c: <Map<String, dynamic>>[] };
    }
  }

  /// Get all recordings for archive view
  Future<List<Map<String, dynamic>>> getAllRecordings(String profileId) async {
    try {
      final recordings = await _qdrant.getRecordingsByProfile(profileId);
      final List<Map<String, dynamic>> archiveEntries = [];
      
      for (final recording in recordings) {
        try {
          final payload = recording['payload'] as Map<String, dynamic>;
          
          // Convert Qdrant data to archive entry format
          final entry = {
            'uuid': payload['uuid'],
            'date': payload['date'],
            'prompt': payload['prompt'],
            'transcript': payload['transcript'],
            'summary': payload['summary'],
            'personalized_summary': payload['personalized_summary'],
            'categories': payload['categories'] ?? [],
            'year': payload['year'],
            'audio_path': await _getAudioPath(profileId, payload['uuid']),
            'is_continuation': payload['is_continuation'] ?? false,
            'original_story_uuid': payload['original_story_uuid'],
            'continuation_prompt': payload['continuation_prompt'],
          };
          
          archiveEntries.add(entry);
        } catch (e) {
          print('Warning: Could not process recording for archive: $e');
        }
      }
      
      // Sort by date (most recent first)
      archiveEntries.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      return archiveEntries;
    } catch (e) {
      print('Error loading archive recordings: $e');
      return [];
    }
  }

  /// Get audio file path for a recording
  Future<String?> _getAudioPath(String profileId, String recordingId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioPath = '${appDir.path}/archive/profile_$profileId/audio/$recordingId.aac';
      final audioFile = File(audioPath);
      
      if (await audioFile.exists()) {
        return audioPath;
      }
    } catch (e) {
      print('Could not find audio file for recording $recordingId: $e');
    }
    return null;
  }

  /// Search for similar memories/recordings
  Future<List<Map<String, dynamic>>> searchSimilarContent({
    required String profileId,
    required String query,
    int limit = 5,
  }) async {
    final queryEmbedding = await EmbeddingService.generateEmbedding(query);
    
    return await _qdrant.searchRecordingsByProfile(
      profileId: profileId,
      embedding: queryEmbedding,
      limit: limit,
    );
  }

  /// Delete recording by UUID
  Future<void> deleteRecording(String uuid) async {
    await _qdrant.deleteRecordingByUuid(uuid);
  }

  /// Delete event by UUID
  Future<void> deleteEvent(String uuid) async {
    await _qdrant.deleteEventByUuid(uuid);
  }

  /// Save audio file (still needed for file storage)
  Future<String> saveAudioToArchive({
    required File audioFile,
    required String profileId,
    required String recordingId,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${appDir.path}/archive/profile_$profileId/audio');
    
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
    
    final audioPath = '${archiveDir.path}/$recordingId.aac';
    await audioFile.copy(audioPath);
    return audioPath;
  }

  // Private method to extract facts using OpenAI (copied from archive_utils.dart)
  Future<ProfileMemory?> _extractFactsWithOpenAI({
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

  /// Generate personalized event summary
  Future<String> _generatePersonalizedEventSummary({
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
NEVER use variables or placeholders (like [person's name], [spouse's name], [partner's name], etc.) in the summary. If you do not know the real name, OMIT the name entirely and write the summary as if the name is not known. Do NOT use brackets or generic terms. Write the summary naturally without any placeholder or variable.

Given the following event metadata and the person's memory (as JSON), write a 1-2 sentence summary of the event that is personalized and context-aware. 
- Use the person's actual name and relationships from the memory if available.
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
}