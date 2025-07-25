import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qdrant_profile_service.dart';
import 'embedding_service.dart';

/// Service for managing story continuations and expansions
class StoryContinuationService {
  final QdrantProfileService _profileService;

  StoryContinuationService(this._profileService);

  /// Append a continuation to an existing story
  Future<void> appendToStory({
    required String profileId,
    required String originalStoryUuid,
    required String continuationTranscript,
    required String continuationPrompt,
    Map<String, dynamic>? continuationMetadata,
  }) async {
    try {
      // Get the original story
      final allRecordings = await _profileService.getAllRecordings(profileId);
      final originalStory = allRecordings.firstWhere(
        (recording) => recording['uuid'] == originalStoryUuid,
        orElse: () => throw Exception('Original story not found'),
      );

      // Create a new UUID for the continuation
      final continuationUuid = const Uuid().v4();
      
      // Merge the continuation with original story metadata (inherit year from original)
      final originalYear = originalStory['year']; // Save original year first
      final mergedMetadata = {
        ...originalStory,
        if (continuationMetadata != null) ...continuationMetadata, // Merge OpenAI metadata first
        // Then set critical fields that must not be overridden
        'uuid': continuationUuid,
        'original_story_uuid': originalStoryUuid,
        'is_continuation': true,
        'continuation_prompt': continuationPrompt,
        'date': DateTime.now().toIso8601String(),
        'prompt': continuationPrompt,
        'year': originalYear, // Ensure year is preserved
      };

      print('DEBUG Continuation: Storing continuation with metadata: $mergedMetadata');
      
      // Store the continuation as a new recording linked to the original
      await _profileService.storeRecording(
        profileId: profileId,
        recordingId: continuationUuid,
        transcript: continuationTranscript,
        metadata: mergedMetadata,
      );

      // Update the original story to reference its continuations
      await _linkStoryParts(profileId, originalStoryUuid, continuationUuid);

      // Generate new consolidated summary for the complete story
      await _updateConsolidatedSummary(profileId, originalStoryUuid);

      print('Story continuation appended successfully');
    } catch (e) {
      print('Error appending story continuation: $e');
      rethrow;
    }
  }

  /// Get all parts of a story (original + continuations) in chronological order
  Future<List<Map<String, dynamic>>> getStoryParts(
    String profileId, 
    String storyUuid,
  ) async {
    try {
      final allRecordings = await _profileService.getAllRecordings(profileId);
      final storyParts = <Map<String, dynamic>>[];

      // Find the original story
      final originalStory = allRecordings.firstWhere(
        (recording) => recording['uuid'] == storyUuid && 
                      (recording['is_continuation'] != true),
        orElse: () => throw Exception('Original story not found'),
      );
      
      storyParts.add({...originalStory, 'part_number': 1});

      // Find all continuations
      final continuations = allRecordings
          .where((recording) => 
              recording['original_story_uuid'] == storyUuid ||
              recording['story_parts']?.contains(storyUuid) == true)
          .toList();

      // Sort continuations by date
      continuations.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
        return dateA.compareTo(dateB);
      });

      // Add continuations with part numbers
      for (int i = 0; i < continuations.length; i++) {
        storyParts.add({
          ...continuations[i],
          'part_number': i + 2,
        });
      }

      return storyParts;
    } catch (e) {
      print('Error getting story parts: $e');
      return [];
    }
  }

  /// Get a consolidated view of a complete story (all parts combined)
  Future<Map<String, dynamic>?> getConsolidatedStory(
    String profileId,
    String storyUuid,
  ) async {
    try {
      final storyParts = await getStoryParts(profileId, storyUuid);
      
      if (storyParts.isEmpty) return null;

      final originalStory = storyParts.first;
      final continuations = storyParts.skip(1).toList();

      // Combine transcripts
      final combinedTranscript = [
        originalStory['transcript'],
        ...continuations.map((part) => part['transcript']),
      ].where((t) => t != null && t.toString().isNotEmpty).join('\n\n--- Continuation ---\n\n');

      // Combine prompts
      final allPrompts = [
        originalStory['prompt'],
        ...continuations.map((part) => part['continuation_prompt'] ?? part['prompt']),
      ].where((p) => p != null && p.toString().isNotEmpty).toList();

      // Merge categories (unique)
      final allCategories = <String>{};
      for (final part in storyParts) {
        final categories = part['categories'] as List<dynamic>? ?? [];
        allCategories.addAll(categories.cast<String>());
      }

      return {
        'uuid': originalStory['uuid'],
        'consolidated_transcript': combinedTranscript,
        'original_prompt': originalStory['prompt'],
        'all_prompts': allPrompts,
        'categories': allCategories.toList(),
        'summary': originalStory['summary'],
        'personalized_summary': originalStory['personalized_summary'],
        'year': originalStory['year'],
        'date': originalStory['date'],
        'total_parts': storyParts.length,
        'story_parts': storyParts,
        'is_multi_part': storyParts.length > 1,
      };
    } catch (e) {
      print('Error consolidating story: $e');
      return null;
    }
  }

  /// Search for stories that could be expanded or continued
  Future<List<Map<String, dynamic>>> findExpandableStories(String profileId) async {
    try {
      final allRecordings = await _profileService.getAllRecordings(profileId);
      print('DEBUG: Total recordings found: ${allRecordings.length}');
      
      // Filter for stories that are not continuations and are expandable
      final expandableStories = allRecordings.where((recording) {
        final isContinuation = recording['is_continuation'] == true;
        final hasTranscript = recording['transcript']?.toString().isNotEmpty == true;
        final transcriptLength = recording['transcript']?.toString().length ?? 0;
        final hasInterestingContent = transcriptLength > 20;
        
        print('DEBUG: Recording UUID: ${recording['uuid']}, isContinuation: $isContinuation, hasTranscript: $hasTranscript, transcriptLength: $transcriptLength, hasInterestingContent: $hasInterestingContent');
        
        // Only include original stories (not continuations) that have content
        return !isContinuation && hasTranscript && hasInterestingContent;
      }).toList();

      // Sort by recency and story richness
      expandableStories.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA); // Most recent first
      });

      return expandableStories.take(10).toList(); // Return top 10 candidates
    } catch (e) {
      print('Error finding expandable stories: $e');
      return [];
    }
  }

  /// Link story parts together for easy retrieval
  Future<void> _linkStoryParts(
    String profileId,
    String originalUuid,
    String continuationUuid,
  ) async {
    try {
      // This would ideally update the original story's metadata to include
      // a reference to its continuations. For now, we rely on the 
      // original_story_uuid field in continuations to link them back.
      
      // In a more sophisticated implementation, we might maintain
      // a separate "story_links" collection in Qdrant or add a 
      // "continuation_uuids" field to the original story.
      
      print('Linked story parts: $originalUuid -> $continuationUuid');
    } catch (e) {
      print('Error linking story parts: $e');
    }
  }

  /// Delete a story continuation
  Future<void> deleteContinuation({
    required String profileId,
    required String continuationUuid,
  }) async {
    try {
      // First, find which original story this continuation belongs to
      String? originalStoryUuid;
      try {
        final allRecordings = await _profileService.getAllRecordings(profileId);
        final continuation = allRecordings.firstWhere(
          (recording) => recording['uuid'] == continuationUuid,
          orElse: () => {},
        );
        originalStoryUuid = continuation['original_story_uuid'];
      } catch (e) {
        print('Could not find original story for continuation: $e');
      }

      // Delete the continuation
      await _profileService.deleteRecording(continuationUuid);
      await _profileService.deleteEvent(continuationUuid);
      
      print('Story continuation deleted: $continuationUuid');

      // If we found the original story, regenerate its consolidated summary
      if (originalStoryUuid != null) {
        print('Regenerating consolidated summary for original story: $originalStoryUuid');
        await _updateConsolidatedSummary(profileId, originalStoryUuid);
      }
    } catch (e) {
      print('Error deleting continuation: $e');
      rethrow;
    }
  }

  /// Get statistics about story continuations for a profile
  Future<Map<String, dynamic>> getContinuationStats(String profileId) async {
    try {
      final allRecordings = await _profileService.getAllRecordings(profileId);
      
      final originalStories = allRecordings.where(
        (r) => r['is_continuation'] != true
      ).length;
      
      final continuations = allRecordings.where(
        (r) => r['is_continuation'] == true
      ).length;
      
      final multiPartStories = <String>{};
      for (final recording in allRecordings) {
        if (recording['is_continuation'] == true) {
          multiPartStories.add(recording['original_story_uuid'] ?? '');
        }
      }
      
      return {
        'total_original_stories': originalStories,
        'total_continuations': continuations,
        'multi_part_stories': multiPartStories.where((s) => s.isNotEmpty).length,
        'average_parts_per_story': originalStories > 0 
            ? (allRecordings.length / originalStories).toStringAsFixed(1)
            : '1.0',
      };
    } catch (e) {
      print('Error getting continuation stats: $e');
      return {
        'total_original_stories': 0,
        'total_continuations': 0,
        'multi_part_stories': 0,
        'average_parts_per_story': '1.0',
      };
    }
  }

  /// Update consolidated summary for a story with multiple sessions
  Future<void> _updateConsolidatedSummary(String profileId, String originalStoryUuid) async {
    try {
      // Get all story parts
      final storyParts = await getStoryParts(profileId, originalStoryUuid);
      if (storyParts.length <= 1) {
        // Single session story doesn't need consolidated summary
        return;
      }

      // Combine all transcripts
      final allTranscripts = storyParts.asMap().entries.map((entry) {
        final index = entry.key;
        final part = entry.value;
        return '--- Session ${index + 1} ---\n\n${part['transcript'] ?? ''}';
      }).join('\n\n');

      // Generate consolidated summary
      final consolidatedSummary = await _generateConsolidatedSummary(allTranscripts, profileId);

      // Update the original story with consolidated summary
      final allRecordings = await _profileService.getAllRecordings(profileId);
      final originalStory = allRecordings.firstWhere(
        (recording) => recording['uuid'] == originalStoryUuid,
        orElse: () => throw Exception('Original story not found'),
      );

      // Update metadata with consolidated summary
      final updatedMetadata = {
        ...originalStory,
        'consolidated_summary': consolidatedSummary,
      };

      // Store updated recording
      await _profileService.storeRecording(
        profileId: profileId,
        recordingId: originalStoryUuid,
        transcript: originalStory['transcript'] ?? '',
        metadata: updatedMetadata,
      );

      print('Consolidated summary updated for story: $originalStoryUuid');
    } catch (e) {
      print('Error updating consolidated summary: $e');
    }
  }

  /// Generate AI consolidated summary (shorter version)
  Future<String> _generateConsolidatedSummary(String allTranscripts, String profileId) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final endpoint = 'https://api.openai.com/v1/chat/completions';
    
    final systemPrompt = '''
You are an expert at creating concise, thoughtful summaries of personal stories that span multiple recording sessions.

Create a flowing narrative summary that:
1. Combines all sessions into one coherent story
2. Highlights the most important progression and key details
3. Maintains the personal, emotional tone
4. Is EXACTLY 1 paragraph (3-4 sentences maximum)
5. Focuses on the essence and meaning of the complete story

Be concise but capture the heart of the story.
''';

    final userPrompt = '''
This is a multi-session story. Please create a concise 1-paragraph summary that weaves all sessions together:

$allTranscripts

Create a brief but meaningful narrative summary of this complete story.
''';

    try {
      final requestBody = {
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 150, // Reduced from 300 to keep it shorter
        'temperature': 0.7,
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ?? 'Summary not available';
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        return 'Summary not available';
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'Summary not available';
    }
  }
}