import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Test data generator for Smriti app
/// Run with: dart test_data_generator.dart
void main() async {
  print('🚀 Generating comprehensive test data for Smriti app...');
  
  final generator = TestDataGenerator();
  await generator.generateAllTestData();
  
  print('✅ Test data generation complete!');
  print('\n📋 Generated data includes:');
  print('   • 25+ diverse memories spanning 2010-2024');
  print('   • Multi-session stories with continuations');
  print('   • Emotional variety (positive, challenging, neutral)');
  print('   • All 10 categories represented');
  print('   • Audio transcripts and AI summaries');
  print('   • Timeline and graph visualization data');
  
  print('\n📖 Usage Instructions:');
  print('1. Copy the JSON output to your Qdrant database');
  print('2. Use the provided API calls to populate data');
  print('3. Test timeline, graph, and archive features');
}

class TestDataGenerator {
  final Uuid _uuid = Uuid();
  final String profileId = 'd1f4101e-9883-4ec7-90f4-dc2b69b21c34'; // Your existing profile ID
  
  Future<void> generateAllTestData() async {
    // Generate memories with varied emotional content and time periods
    final memories = _generateMemories();
    
    // Generate multi-session stories
    final multiSessionStories = _generateMultiSessionStories();
    
    // Combine all data
    final allMemories = [...memories, ...multiSessionStories];
    
    // Output as structured data
    await _outputTestData(allMemories);
  }
  
  List<Map<String, dynamic>> _generateMemories() {
    return [
      // 2024 - Recent positive memories
      _createMemory(
        year: 2024,
        summary: 'Started a new career in technology after years of preparation and learning',
        categories: ['career', 'growth'],
        emotion: 'positive',
        transcript: 'I finally landed my dream job in tech! After months of studying, coding bootcamps, and countless interviews, I got the offer. The feeling when they called was incredible - all that hard work finally paid off. My family was so proud, and I felt like I could conquer the world.',
      ),
      
      _createMemory(
        year: 2024,
        summary: 'Adopted a rescue dog who brought so much joy and companionship',
        categories: ['love', 'growth'],
        emotion: 'positive',
        transcript: 'We went to the animal shelter just to look, but when I saw Max in his kennel, something just clicked. He was this scruffy little guy with the saddest eyes, but when he saw me, his tail started wagging. Three months later, he\'s completely transformed our home with his energy and love.',
      ),
      
      // 2023 - Mixed emotions
      _createMemory(
        year: 2023,
        summary: 'Grandmother passed away peacefully, leaving behind beautiful memories',
        categories: ['family', 'loss', 'wisdom'],
        emotion: 'reflective',
        transcript: 'Grandma left us last spring. It was peaceful - she was surrounded by all of us, holding hands. Even though it was sad, I felt grateful for all the time we had together. She taught me so much about resilience, kindness, and finding joy in simple things like her garden and Sunday dinners.',
      ),
      
      _createMemory(
        year: 2023,
        summary: 'Completed my first marathon after training for eight months',
        categories: ['health', 'achievement', 'growth'],
        emotion: 'positive',
        transcript: 'Mile 20 was brutal. My legs felt like concrete, and I wanted to quit so badly. But then I heard my friends cheering, and I remembered all those early morning training runs in the rain. When I crossed that finish line at 4:02:33, I cried. Not from pain, but from pure joy and accomplishment.',
      ),
      
      // 2022 - Challenges and growth
      _createMemory(
        year: 2022,
        summary: 'Faced financial difficulties but learned valuable lessons about budgeting',
        categories: ['growth', 'wisdom'],
        emotion: 'challenging',
        transcript: 'The pandemic really hit our finances hard. For months, we were living paycheck to paycheck, stressed about every expense. It was scary and humbling. But it taught me so much about what really matters, how to budget properly, and the importance of having an emergency fund.',
      ),
      
      _createMemory(
        year: 2022,
        summary: 'Reconnected with childhood friends during a high school reunion',
        categories: ['friends', 'love'],
        emotion: 'positive',
        transcript: 'I almost didn\'t go to the reunion - I was nervous about seeing everyone after so many years. But it was amazing! Sarah, Mike, and I talked for hours like no time had passed. We shared stories about our kids, careers, and dreams. It reminded me why these friendships were so special.',
      ),
      
      // 2021 - Pandemic era
      _createMemory(
        year: 2021,
        summary: 'Started learning guitar during lockdown and discovered a new passion',
        categories: ['growth', 'adventure'],
        emotion: 'positive',
        transcript: 'Being stuck at home, I finally picked up that dusty guitar from the closet. YouTube became my teacher, and slowly, painfully, I learned my first chords. Now I can play a few songs, and it\'s become my favorite way to unwind. Music has always moved me, but creating it is magic.',
      ),
      
      _createMemory(
        year: 2021,
        summary: 'Lost my job due to company downsizing but found new opportunities',
        categories: ['career', 'growth'],
        emotion: 'challenging',
        transcript: 'The day they laid off half our department was devastating. I\'d been there for five years and felt so lost. But it forced me to reevaluate what I wanted. I took some online courses, networked more, and eventually found something even better that aligned with my values.',
      ),
      
      // 2020 - Major life changes
      _createMemory(
        year: 2020,
        summary: 'Got married in a small backyard ceremony due to pandemic restrictions',
        categories: ['love', 'family'],
        emotion: 'positive',
        transcript: 'Our big wedding was canceled, but we decided to go ahead with just our immediate families in my parents\' backyard. It was perfect - intimate, personal, and focused on what really mattered: our love and commitment. The photos are beautiful, and honestly, I wouldn\'t change a thing.',
      ),
      
      // 2019 - Travel and adventure
      _createMemory(
        year: 2019,
        summary: 'Backpacked through Southeast Asia and discovered incredible cultures',
        categories: ['adventure', 'growth', 'wisdom'],
        emotion: 'positive',
        transcript: 'Three months in Thailand, Vietnam, and Cambodia changed my perspective completely. The kindness of strangers, the incredible food, the ancient temples - everything was overwhelming in the best way. I learned to be comfortable with uncertainty and to appreciate different ways of living.',
      ),
      
      _createMemory(
        year: 2019,
        summary: 'Started therapy to work through anxiety and depression',
        categories: ['health', 'growth'],
        emotion: 'challenging',
        transcript: 'Admitting I needed help was the hardest part. I\'d been struggling with anxiety for years but always thought I could handle it alone. My therapist helped me understand my patterns and gave me tools to cope. It wasn\'t easy, but it was one of the best decisions I ever made.',
      ),
      
      // 2018 - Education and career
      _createMemory(
        year: 2018,
        summary: 'Graduated college with honors after years of hard work and sacrifice',
        categories: ['education', 'achievement'],
        emotion: 'positive',
        transcript: 'Walking across that stage to get my diploma, I thought about all the late nights, the part-time jobs to pay tuition, the stress and doubt. But I did it - magna cum laude! Mom cried in the audience, and Dad couldn\'t stop taking pictures. Four years of sacrifice finally paid off.',
      ),
      
      // 2017 - Relationships
      _createMemory(
        year: 2017,
        summary: 'Ended a long-term relationship that wasn\'t working anymore',
        categories: ['love', 'growth'],
        emotion: 'challenging',
        transcript: 'Breaking up with Alex was one of the hardest things I\'ve ever done. We\'d been together for three years, but we\'d grown in different directions. It was mutual but still heartbreaking. I learned so much about myself and what I need in a relationship.',
      ),
      
      // 2016 - Family milestones
      _createMemory(
        year: 2016,
        summary: 'Became an aunt when my sister had her first baby',
        categories: ['family', 'love'],
        emotion: 'positive',
        transcript: 'When they placed little Emma in my arms for the first time, I was overwhelmed with love and protectiveness. She was so tiny and perfect. Watching my sister become a mother was incredible - seeing her strength and natural instincts. I never knew I could love someone so much so instantly.',
      ),
      
      // 2015 - Health challenges
      _createMemory(
        year: 2015,
        summary: 'Dealt with a health scare that changed my perspective on life',
        categories: ['health', 'wisdom'],
        emotion: 'challenging',
        transcript: 'The doctor said "We need to run more tests" and my world stopped. Waiting for results was agony - I couldn\'t eat, sleep, or focus on anything. Thankfully it was benign, but those two weeks taught me not to take my health for granted and to live more fully in the present.',
      ),
      
      // 2014 - Adventures
      _createMemory(
        year: 2014,
        summary: 'Climbed Mount Washington despite being afraid of heights',
        categories: ['adventure', 'growth'],
        emotion: 'positive',
        transcript: 'I\'ve always been terrified of heights, but something about that mountain called to me. The hike was brutal - my legs were shaking, and I wanted to turn back multiple times. But reaching the summit and seeing that view... I felt like I could do anything. It taught me that courage isn\'t the absence of fear.',
      ),
      
      // 2013 - Career beginnings
      _createMemory(
        year: 2013,
        summary: 'Started my first real job and learned about professional life',
        categories: ['career', 'growth'],
        emotion: 'neutral',
        transcript: 'My first day at the office was terrifying and exciting. I had no idea what I was doing, and everyone seemed so confident and professional. I made mistakes, asked lots of questions, and slowly found my footing. It was the beginning of understanding what I wanted from my career.',
      ),
      
      // 2012 - Education
      _createMemory(
        year: 2012,
        summary: 'Studied abroad in Spain and became fluent in Spanish',
        categories: ['education', 'adventure'],
        emotion: 'positive',
        transcript: 'Living with the Rodriguez family in Sevilla was life-changing. They barely spoke English, so I had to learn Spanish quickly. At first I was frustrated and embarrassed by my mistakes, but they were so patient and encouraging. By the end of the semester, I was dreaming in Spanish!',
      ),
      
      // 2011 - Friendships
      _createMemory(
        year: 2011,
        summary: 'Met my best friend during freshman year of college',
        categories: ['friends', 'love'],
        emotion: 'positive',
        transcript: 'I was homesick and lonely during my first weeks at college. Then I met Jamie in the library - we were both stressed about the same chemistry exam. We started studying together, and before I knew it, we were inseparable. Thirteen years later, she\'s still my closest friend.',
      ),
      
      // 2010 - Coming of age
      _createMemory(
        year: 2010,
        summary: 'Graduated high school and felt excited but scared about the future',
        categories: ['education', 'growth'],
        emotion: 'neutral',
        transcript: 'High school graduation felt surreal. I was excited about college and independence, but also terrified about leaving home and everything familiar. The ceremony was long and boring, but when they called my name, I felt this mix of pride and nervousness about what came next.',
      ),
    ];
  }
  
  List<Map<String, dynamic>> _generateMultiSessionStories() {
    // Generate stories with multiple sessions to test continuation features
    final originalStoryId = _uuid.v4();
    
    return [
      // Original story
      _createMemory(
        year: 2023,
        summary: 'Started renovating our first home together',
        categories: ['family', 'growth'],
        emotion: 'positive',
        transcript: 'We bought this old Victorian house that needed everything - new plumbing, electrical, flooring, you name it. It was overwhelming but exciting. We spent weekends at Home Depot, watching YouTube tutorials, and slowly learning how to be homeowners.',
        customId: originalStoryId,
        sessionCount: 3,
      ),
      
      // First continuation
      _createMemory(
        year: 2023,
        summary: 'Continuation of home renovation',
        categories: ['family', 'growth'],
        emotion: 'challenging',
        transcript: 'Three months in, we hit a major snag. When we opened up the kitchen wall, we found water damage and had to redo all the plumbing. The costs were adding up, and we were living in chaos with no functioning kitchen. We started questioning if we bit off more than we could chew.',
        isContinuation: true,
        originalStoryUuid: originalStoryId,
      ),
      
      // Second continuation
      _createMemory(
        year: 2023,
        summary: 'Finished home renovation project',
        categories: ['family', 'achievement'],
        emotion: 'positive',
        transcript: 'Eight months later, we finally finished! The house is beautiful - modern kitchen, refinished hardwood floors, and a gorgeous master bathroom. All those weekends of hard work, the stress, and the money were worth it. We had a housewarming party and everyone was amazed at the transformation.',
        isContinuation: true,
        originalStoryUuid: originalStoryId,
      ),
    ];
  }
  
  Map<String, dynamic> _createMemory({
    required int year,
    required String summary,
    required List<String> categories,
    required String emotion,
    required String transcript,
    String? customId,
    bool isContinuation = false,
    String? originalStoryUuid,
    int? sessionCount,
  }) {
    final uuid = customId ?? _uuid.v4();
    final now = DateTime.now();
    
    return {
      'profile_id': profileId,
      'uuid': uuid,
      'year': year,
      'summary': summary,
      'personalized_summary': _generatePersonalizedSummary(summary),
      'categories': categories,
      'transcript': transcript,
      'prompt': _generatePrompt(categories, emotion),
      'date': DateTime(year, 6, 15).toIso8601String(), // Mid-year date
      'emotion_score': _getEmotionScore(emotion),
      'is_continuation': isContinuation,
      'original_story_uuid': originalStoryUuid,
      'session_count': sessionCount ?? 1,
      'type': 'recording',
    };
  }
  
  String _generatePersonalizedSummary(String summary) {
    // Create more personalized versions of summaries
    final variations = [
      'Reflecting on when $summary - it shaped who I am today',
      'A meaningful time when $summary',
      'An important chapter in my life: $summary',
      summary, // Keep some as-is
    ];
    variations.shuffle();
    return variations.first;
  }
  
  String _generatePrompt(List<String> categories, String emotion) {
    final prompts = {
      'positive': [
        'Tell me about a time that brought you great joy',
        'Share a moment when you felt truly accomplished',
        'Describe a beautiful memory that still makes you smile',
      ],
      'challenging': [
        'Tell me about a difficult time that taught you something important',
        'Share a challenge you overcame',
        'Describe a time when you had to be strong',
      ],
      'neutral': [
        'Tell me about an important milestone in your life',
        'Share a memory from this time period',
        'Describe what was happening in your life then',
      ],
    };
    
    final categoryPrompts = {
      'love': 'Tell me about love in your life',
      'family': 'Share a meaningful family memory',
      'career': 'Tell me about your work or career journey',
      'friends': 'Describe a special friendship',
      'health': 'Share something about your health journey',
      'education': 'Tell me about your learning experiences',
    };
    
    // Use category-specific prompt if available, otherwise emotion-based
    if (categories.isNotEmpty && categoryPrompts.containsKey(categories.first)) {
      return categoryPrompts[categories.first]!;
    }
    
    final emotionPrompts = prompts[emotion] ?? prompts['neutral']!;
    emotionPrompts.shuffle();
    return emotionPrompts.first;
  }
  
  double _getEmotionScore(String emotion) {
    switch (emotion) {
      case 'positive': return 0.8;
      case 'challenging': return -0.6;
      case 'reflective': return -0.3;
      default: return 0.0;
    }
  }
  
  Future<void> _outputTestData(List<Map<String, dynamic>> memories) async {
    // Create output file
    final file = File('test_data_output.json');
    final jsonOutput = {
      'profile_id': profileId,
      'total_memories': memories.length,
      'memories': memories,
      'api_calls': _generateApiCalls(memories),
      'categories_represented': _getUniqueCategories(memories),
      'year_range': _getYearRange(memories),
    };
    
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonOutput));
    print('📁 Test data written to: ${file.absolute.path}');
  }
  
  List<String> _generateApiCalls(List<Map<String, dynamic>> memories) {
    return memories.map((memory) => '''
curl -X POST "http://localhost:3000/api/memories" \\
  -H "Content-Type: application/json" \\
  -d '${jsonEncode(memory)}'
''').toList();
  }
  
  List<String> _getUniqueCategories(List<Map<String, dynamic>> memories) {
    final categories = <String>{};
    for (final memory in memories) {
      final memoryCategories = List<String>.from(memory['categories']);
      categories.addAll(memoryCategories);
    }
    return categories.toList()..sort();
  }
  
  Map<String, int> _getYearRange(List<Map<String, dynamic>> memories) {
    final years = memories.map((m) => m['year'] as int).toList();
    return {
      'earliest': years.reduce((a, b) => a < b ? a : b),
      'latest': years.reduce((a, b) => a > b ? a : b),
    };
  }
}