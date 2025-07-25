import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/profile_memory.dart';
import 'qdrant_profile_service.dart';
import 'embedding_service.dart';

/// Service for generating intelligent, contextual prompts based on user's stories and memories
class PromptGenerationService {
  final QdrantProfileService _profileService;
  final Random _random = Random();

  PromptGenerationService(this._profileService);

  /// Generate a contextual follow-up prompt based on existing stories
  Future<String> generateFollowUpPrompt({
    required String profileId,
    String? baseStory,
    List<String>? existingPrompts,
  }) async {
    try {
      // Get user's memory and recent stories
      final memory = await _profileService.getProfileMemory(profileId);
      final recentRecordings = await _profileService.getAllRecordings(profileId);
      
      // Limit to last 10 recordings to avoid overwhelming the AI
      final recentStories = recentRecordings.take(10).toList();
      
      // Generate context-aware prompt
      final prompt = await _generateContextualPrompt(
        memory: memory,
        recentStories: recentStories,
        baseStory: baseStory,
        existingPrompts: existingPrompts ?? [],
      );
      
      return prompt;
    } catch (e) {
      print('Error generating follow-up prompt: $e');
      return _getFallbackPrompt();
    }
  }

  /// Generate a completely new, diverse prompt to avoid saturation
  Future<String> generateDiversePrompt({
    required String profileId,
    List<String>? usedCategories,
  }) async {
    try {
      final memory = await _profileService.getProfileMemory(profileId);
      final allRecordings = await _profileService.getAllRecordings(profileId);
      
      // Analyze patterns in existing stories
      final storyAnalysis = _analyzeStoryPatterns(allRecordings);
      
      // Generate a prompt that explores underexplored areas
      final prompt = await _generateDiversityPrompt(
        memory: memory,
        storyAnalysis: storyAnalysis,
        usedCategories: usedCategories ?? [],
      );
      
      return prompt;
    } catch (e) {
      print('Error generating diverse prompt: $e');
      return _getFallbackPrompt();
    }
  }

  /// Generate a prompt that continues or expands on an existing story
  Future<String> generateContinuationPrompt({
    required String profileId,
    required Map<String, dynamic> existingStory,
  }) async {
    try {
      final memory = await _profileService.getProfileMemory(profileId);
      
      final continuationPrompt = await _generateStoryContination(
        memory: memory,
        existingStory: existingStory,
      );
      
      return continuationPrompt;
    } catch (e) {
      print('Error generating continuation prompt: $e');
      return _getFallbackPrompt();
    }
  }

  Future<String> _generateContextualPrompt({
    required ProfileMemory memory,
    required List<Map<String, dynamic>> recentStories,
    String? baseStory,
    required List<String> existingPrompts,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final endpoint = 'https://api.openai.com/v1/chat/completions';
    
    final systemPrompt = '''
You are an expert at generating thoughtful, personal prompts for memory collection. 

Based on the user's profile memory and recent stories, generate a single, specific follow-up question that:
1. Builds naturally on what they've shared
2. Explores deeper emotional or experiential aspects
3. Avoids repeating previous prompts
4. Feels personal and meaningful
5. Is specific enough to elicit a detailed story

Respond with ONLY the prompt question, no explanation or additional text.
''';

    final contextInfo = {
      'profile_name': memory.name,
      'birth_place': memory.birthPlace,
      'recent_stories': recentStories.map((s) => {
        'prompt': s['prompt'],
        'summary': s['personalized_summary'] ?? s['summary'],
        'categories': s['categories'],
        'year': s['year'],
      }).toList(),
      'existing_prompts': existingPrompts,
      'base_story': baseStory,
    };

    final userPrompt = '''
Profile Context: ${jsonEncode(contextInfo)}

Generate a thoughtful follow-up prompt that naturally continues the conversation based on their recent stories and background.
''';

    return await _callOpenAI(systemPrompt, userPrompt) ?? _getFallbackPrompt();
  }

  Future<String> _generateDiversityPrompt({
    required ProfileMemory memory,
    required Map<String, dynamic> storyAnalysis,
    required List<String> usedCategories,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final endpoint = 'https://api.openai.com/v1/chat/completions';
    
    final systemPrompt = '''
You are an expert at generating diverse, exploratory prompts for memory collection.

Based on the analysis of existing stories, generate a prompt that:
1. Explores underrepresented life areas or time periods
2. Encourages stories from different categories (love, family, career, wisdom, friends, education, health, adventure, loss, growth)
3. Asks about different types of experiences (challenges, achievements, relationships, learning moments)
4. Varies the time frame (childhood, adolescence, recent years, specific decades)
5. Is engaging and specific enough to elicit a meaningful story

Respond with ONLY the prompt question, no explanation.
''';

    final analysisInfo = {
      'profile_name': memory.name,
      'story_analysis': storyAnalysis,
      'used_categories': usedCategories,
      'underexplored_areas': _findUnderexploredAreas(storyAnalysis),
    };

    final userPrompt = '''
Analysis: ${jsonEncode(analysisInfo)}

Generate a diverse prompt that explores new territory in their life story.
''';

    return await _callOpenAI(systemPrompt, userPrompt) ?? _getFallbackPrompt();
  }

  Future<String> _generateStoryContination({
    required ProfileMemory memory,
    required Map<String, dynamic> existingStory,
  }) async {
    final systemPrompt = '''
You generate follow-up questions for multi-session story collection.

CONTEXT: This story may have multiple sessions. Focus on the MOST RECENT session to generate the next logical question.

RULES:
1. Read all sessions, but focus on the most recent one
2. Generate a question that naturally continues from where they last left off
3. Reference specific details from the most recent session
4. Build on the progression of the story across sessions
5. Do NOT repeat what was already asked in previous sessions

Your question should feel like a natural continuation of their storytelling journey.

Respond with ONLY the question.''';

    print('DEBUG Prompt Gen: Full story data structure: ${existingStory.toString()}');
    
    // Check if we have story_parts (from getConsolidatedStory) or sessions directly
    List<dynamic> sessions = [];
    if (existingStory['story_parts'] != null) {
      sessions = existingStory['story_parts'] as List<dynamic>;
      print('DEBUG Prompt Gen: Using story_parts, found ${sessions.length} parts');
    } else if (existingStory['sessions'] != null) {
      sessions = existingStory['sessions'] as List<dynamic>;
      print('DEBUG Prompt Gen: Using sessions, found ${sessions.length} sessions');
    } else {
      // Fallback to treating the whole story as a single session
      sessions = [existingStory];
      print('DEBUG Prompt Gen: Using fallback single session');
    }
    
    final mostRecentSession = sessions.isNotEmpty ? sessions.last : {};
    final allTranscripts = sessions.map((s) => s['transcript'] ?? '').join(' ... ');
    
    final recentTranscript = mostRecentSession['transcript'] ?? '';
    final recentPrompt = mostRecentSession['prompt'] ?? '';
    final originalTranscript = sessions.isNotEmpty ? sessions.first['transcript'] ?? '' : '';
    
    print('DEBUG Prompt Gen: Original transcript: "$originalTranscript"');
    print('DEBUG Prompt Gen: Most recent transcript: "$recentTranscript"');
    print('DEBUG Prompt Gen: Recent prompt: "$recentPrompt"');
    print('DEBUG Prompt Gen: All transcripts: "$allTranscripts"');
    
    final userPrompt = '''
Story progression:
- Original story: "$originalTranscript"
- All sessions: "$allTranscripts"
- Most recent session: "$recentTranscript"
- Last prompt used: "$recentPrompt"

Generate the next logical follow-up question that continues naturally from their most recent session.''';

    print('DEBUG Prompt Gen: Sending prompt to AI: $userPrompt');

    return await _callOpenAI(systemPrompt, userPrompt) ?? _getFallbackPrompt();
  }

  Future<String?> _callOpenAI(String systemPrompt, String userPrompt) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      
      final requestBody = {
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 150,
        'temperature': 0.3, // Lower temperature for more focused responses
      };
      
      print('DEBUG: OpenAI request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('DEBUG: OpenAI response status: ${response.statusCode}');
      print('DEBUG: OpenAI response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content']?.trim();
        print('DEBUG: OpenAI generated content: "$content"');
        return content;
      } else {
        print('DEBUG: OpenAI API error - Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('DEBUG: OpenAI API exception: $e');
    }
    return null;
  }

  Map<String, dynamic> _analyzeStoryPatterns(List<Map<String, dynamic>> stories) {
    final categoryCount = <String, int>{};
    final yearCount = <String, int>{};
    final promptTypes = <String>[];
    
    for (final story in stories) {
      // Count categories
      final categories = story['categories'] as List<dynamic>? ?? [];
      for (final category in categories) {
        categoryCount[category.toString()] = (categoryCount[category.toString()] ?? 0) + 1;
      }
      
      // Count years/decades
      final year = story['year'];
      if (year != null) {
        final decade = '${(year ~/ 10) * 10}s';
        yearCount[decade] = (yearCount[decade] ?? 0) + 1;
      }
      
      // Collect prompt types
      final prompt = story['prompt']?.toString() ?? '';
      promptTypes.add(prompt);
    }
    
    return {
      'category_distribution': categoryCount,
      'time_period_distribution': yearCount,
      'total_stories': stories.length,
      'prompt_types': promptTypes,
    };
  }

  List<String> _findUnderexploredAreas(Map<String, dynamic> analysis) {
    const allCategories = [
      'love', 'family', 'career', 'wisdom', 'friends', 'education', 
      'health', 'adventure', 'loss', 'growth'
    ];
    
    final categoryCount = analysis['category_distribution'] as Map<String, dynamic>? ?? {};
    final underexplored = <String>[];
    
    for (final category in allCategories) {
      final count = categoryCount[category] ?? 0;
      if (count < 2) { // Less than 2 stories in this category
        underexplored.add(category);
      }
    }
    
    return underexplored;
  }

  String _getFallbackPrompt() {
    final fallbackPrompts = [
      "Tell me about a moment when you felt truly proud of yourself.",
      "What's a challenge you overcame that taught you something important?",
      "Describe a friendship that changed your perspective on life.",
      "What's a family tradition or memory that means a lot to you?",
      "Tell me about a time when you took a risk that paid off.",
      "What's something you learned from a mistake or failure?",
      "Describe a place that holds special meaning for you.",
      "Tell me about someone who influenced your life in an unexpected way.",
      "What's a skill or hobby you're passionate about? How did you discover it?",
      "Describe a moment when you felt completely content and happy.",
    ];
    
    return fallbackPrompts[_random.nextInt(fallbackPrompts.length)];
  }
}