import '../storage/qdrant_profile_service.dart';
import 'package:uuid/uuid.dart';

/// Test data importer for Smriti app
/// Use this to populate your app with realistic test data
class TestDataImporter {
  final QdrantProfileService _profileService;
  final Uuid _uuid = const Uuid();
  
  TestDataImporter(this._profileService);
  
  /// Import all test data for the given profile
  Future<void> importTestData(String profileId) async {
    print('🚀 Importing test data for profile: $profileId');
    
    try {
      await _profileService.initialize();
      
      final testMemories = _getTestMemories(profileId);
      
      for (int i = 0; i < testMemories.length; i++) {
        final memory = testMemories[i];
        print('📝 Importing memory ${i + 1}/${testMemories.length}: ${memory['summary']}');
        
        try {
          await _profileService.updateProfileMemoryWithStory(
            profileId: profileId,
            metadata: memory,
            transcript: memory['transcript'],
          );
          
          // Small delay to avoid overwhelming the API
          await Future.delayed(Duration(milliseconds: 100));
          
        } catch (e) {
          print('❌ Error importing memory ${i + 1}: $e');
        }
      }
      
      print('✅ Test data import completed!');
      print('📊 Imported ${testMemories.length} memories');
      
    } catch (e) {
      print('❌ Error during test data import: $e');
      rethrow;
    }
  }
  
  List<Map<String, dynamic>> _getTestMemories(String profileId) {
    // Generate UUIDs for multi-session story
    final homeRenovationOriginal = _uuid.v4();
    
    return [
      // 2024 - Recent positive memories
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2024,
        'summary': 'Started a new career in technology after years of preparation and learning',
        'personalized_summary': 'A meaningful time when I started a new career in technology after years of preparation and learning',
        'categories': ['career', 'growth'],
        'transcript': 'I finally landed my dream job in tech! After months of studying, coding bootcamps, and countless interviews, I got the offer. The feeling when they called was incredible - all that hard work finally paid off. My family was so proud, and I felt like I could conquer the world.',
        'prompt': 'Tell me about your work or career journey',
        'date': DateTime(2024, 6, 15).toIso8601String(),
        'type': 'recording',
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2024,
        'summary': 'Adopted a rescue dog who brought so much joy and companionship',
        'personalized_summary': 'Reflecting on when I adopted a rescue dog who brought so much joy and companionship - it shaped who I am today',
        'categories': ['love', 'growth'],
        'transcript': 'We went to the animal shelter just to look, but when I saw Max in his kennel, something just clicked. He was this scruffy little guy with the saddest eyes, but when he saw me, his tail started wagging. Three months later, he\'s completely transformed our home with his energy and love.',
        'prompt': 'Tell me about love in your life',
        'date': DateTime(2024, 8, 20).toIso8601String(),
        'type': 'recording',
      },
      
      // 2023 - Mixed emotions
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2023,
        'summary': 'Grandmother passed away peacefully, leaving behind beautiful memories',
        'personalized_summary': 'An important chapter in my life: Grandmother passed away peacefully, leaving behind beautiful memories',
        'categories': ['family', 'loss', 'wisdom'],
        'transcript': 'Grandma left us last spring. It was peaceful - she was surrounded by all of us, holding hands. Even though it was sad, I felt grateful for all the time we had together. She taught me so much about resilience, kindness, and finding joy in simple things like her garden and Sunday dinners.',
        'prompt': 'Share a meaningful family memory',
        'date': DateTime(2023, 4, 10).toIso8601String(),
        'type': 'recording',
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2023,
        'summary': 'Completed my first marathon after training for eight months',
        'personalized_summary': 'A meaningful time when I completed my first marathon after training for eight months',
        'categories': ['health', 'growth'],
        'transcript': 'Mile 20 was brutal. My legs felt like concrete, and I wanted to quit so badly. But then I heard my friends cheering, and I remembered all those early morning training runs in the rain. When I crossed that finish line at 4:02:33, I cried. Not from pain, but from pure joy and accomplishment.',
        'prompt': 'Tell me about a time that brought you great joy',
        'date': DateTime(2023, 10, 15).toIso8601String(),
        'type': 'recording',
      },
      
      // Multi-session story - Home renovation
      {
        'profile_id': profileId,
        'uuid': homeRenovationOriginal,
        'year': 2023,
        'summary': 'Started renovating our first home together',
        'personalized_summary': 'Started renovating our first home together',
        'categories': ['family', 'growth'],
        'transcript': 'We bought this old Victorian house that needed everything - new plumbing, electrical, flooring, you name it. It was overwhelming but exciting. We spent weekends at Home Depot, watching YouTube tutorials, and slowly learning how to be homeowners.',
        'prompt': 'Share a meaningful family memory',
        'date': DateTime(2023, 2, 1).toIso8601String(),
        'type': 'recording',
        'session_count': 3,
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2023,
        'summary': 'Hit major challenges during home renovation',
        'personalized_summary': 'Hit major challenges during home renovation',
        'categories': ['family', 'growth'],
        'transcript': 'Three months in, we hit a major snag. When we opened up the kitchen wall, we found water damage and had to redo all the plumbing. The costs were adding up, and we were living in chaos with no functioning kitchen. We started questioning if we bit off more than we could chew.',
        'prompt': 'Continue telling me about your home renovation',
        'date': DateTime(2023, 5, 1).toIso8601String(),
        'type': 'recording',
        'is_continuation': true,
        'original_story_uuid': homeRenovationOriginal,
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2023,
        'summary': 'Successfully completed home renovation project',
        'personalized_summary': 'Successfully completed home renovation project',
        'categories': ['family', 'growth'],
        'transcript': 'Eight months later, we finally finished! The house is beautiful - modern kitchen, refinished hardwood floors, and a gorgeous master bathroom. All those weekends of hard work, the stress, and the money were worth it. We had a housewarming party and everyone was amazed at the transformation.',
        'prompt': 'Tell me how the home renovation ended',
        'date': DateTime(2023, 9, 15).toIso8601String(),
        'type': 'recording',
        'is_continuation': true,
        'original_story_uuid': homeRenovationOriginal,
      },
      
      // 2022 - Challenges and growth
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2022,
        'summary': 'Faced financial difficulties but learned valuable lessons about budgeting',
        'personalized_summary': 'Tell me about a difficult time that taught you something important',
        'categories': ['growth', 'wisdom'],
        'transcript': 'The pandemic really hit our finances hard. For months, we were living paycheck to paycheck, stressed about every expense. It was scary and humbling. But it taught me so much about what really matters, how to budget properly, and the importance of having an emergency fund.',
        'prompt': 'Tell me about a difficult time that taught you something important',
        'date': DateTime(2022, 3, 10).toIso8601String(),
        'type': 'recording',
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2022,
        'summary': 'Reconnected with childhood friends during a high school reunion',
        'personalized_summary': 'Reflecting on when I reconnected with childhood friends during a high school reunion - it shaped who I am today',
        'categories': ['friends', 'love'],
        'transcript': 'I almost didn\'t go to the reunion - I was nervous about seeing everyone after so many years. But it was amazing! Sarah, Mike, and I talked for hours like no time had passed. We shared stories about our kids, careers, and dreams. It reminded me why these friendships were so special.',
        'prompt': 'Describe a special friendship',
        'date': DateTime(2022, 7, 20).toIso8601String(),
        'type': 'recording',
      },
      
      // 2021 - Pandemic era
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2021,
        'summary': 'Started learning guitar during lockdown and discovered a new passion',
        'personalized_summary': 'A meaningful time when I started learning guitar during lockdown and discovered a new passion',
        'categories': ['growth', 'adventure'],
        'transcript': 'Being stuck at home, I finally picked up that dusty guitar from the closet. YouTube became my teacher, and slowly, painfully, I learned my first chords. Now I can play a few songs, and it\'s become my favorite way to unwind. Music has always moved me, but creating it is magic.',
        'prompt': 'Tell me about a time that brought you great joy',
        'date': DateTime(2021, 4, 15).toIso8601String(),
        'type': 'recording',
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2021,
        'summary': 'Lost my job due to company downsizing but found new opportunities',
        'personalized_summary': 'Lost my job due to company downsizing but found new opportunities',
        'categories': ['career', 'growth'],
        'transcript': 'The day they laid off half our department was devastating. I\'d been there for five years and felt so lost. But it forced me to reevaluate what I wanted. I took some online courses, networked more, and eventually found something even better that aligned with my values.',
        'prompt': 'Tell me about a challenge you overcame',
        'date': DateTime(2021, 1, 8).toIso8601String(),
        'type': 'recording',
      },
      
      // 2020 - Major life changes
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2020,
        'summary': 'Got married in a small backyard ceremony due to pandemic restrictions',
        'personalized_summary': 'An important chapter in my life: Got married in a small backyard ceremony due to pandemic restrictions',
        'categories': ['love', 'family'],
        'transcript': 'Our big wedding was canceled, but we decided to go ahead with just our immediate families in my parents\' backyard. It was perfect - intimate, personal, and focused on what really mattered: our love and commitment. The photos are beautiful, and honestly, I wouldn\'t change a thing.',
        'prompt': 'Tell me about love in your life',
        'date': DateTime(2020, 8, 15).toIso8601String(),
        'type': 'recording',
      },
      
      // 2019 - Travel and adventure
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2019,
        'summary': 'Backpacked through Southeast Asia and discovered incredible cultures',
        'personalized_summary': 'Reflecting on when I backpacked through Southeast Asia and discovered incredible cultures - it shaped who I am today',
        'categories': ['adventure', 'growth', 'wisdom'],
        'transcript': 'Three months in Thailand, Vietnam, and Cambodia changed my perspective completely. The kindness of strangers, the incredible food, the ancient temples - everything was overwhelming in the best way. I learned to be comfortable with uncertainty and to appreciate different ways of living.',
        'prompt': 'Describe a beautiful memory that still makes you smile',
        'date': DateTime(2019, 6, 20).toIso8601String(),
        'type': 'recording',
      },
      
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2019,
        'summary': 'Started therapy to work through anxiety and depression',
        'personalized_summary': 'Started therapy to work through anxiety and depression',
        'categories': ['health', 'growth'],
        'transcript': 'Admitting I needed help was the hardest part. I\'d been struggling with anxiety for years but always thought I could handle it alone. My therapist helped me understand my patterns and gave me tools to cope. It wasn\'t easy, but it was one of the best decisions I ever made.',
        'prompt': 'Share something about your health journey',
        'date': DateTime(2019, 2, 10).toIso8601String(),
        'type': 'recording',
      },
      
      // 2018 - Education and career
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2018,
        'summary': 'Graduated college with honors after years of hard work and sacrifice',
        'personalized_summary': 'A meaningful time when I graduated college with honors after years of hard work and sacrifice',
        'categories': ['education', 'growth'],
        'transcript': 'Walking across that stage to get my diploma, I thought about all the late nights, the part-time jobs to pay tuition, the stress and doubt. But I did it - magna cum laude! Mom cried in the audience, and Dad couldn\'t stop taking pictures. Four years of sacrifice finally paid off.',
        'prompt': 'Tell me about your learning experiences',
        'date': DateTime(2018, 5, 15).toIso8601String(),
        'type': 'recording',
      },
      
      // 2017 - Relationships
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2017,
        'summary': 'Ended a long-term relationship that wasn\'t working anymore',
        'personalized_summary': 'Ended a long-term relationship that wasn\'t working anymore',
        'categories': ['love', 'growth'],
        'transcript': 'Breaking up with Alex was one of the hardest things I\'ve ever done. We\'d been together for three years, but we\'d grown in different directions. It was mutual but still heartbreaking. I learned so much about myself and what I need in a relationship.',
        'prompt': 'Tell me about a time when you had to be strong',
        'date': DateTime(2017, 9, 5).toIso8601String(),
        'type': 'recording',
      },
      
      // 2016 - Family milestones
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2016,
        'summary': 'Became an aunt when my sister had her first baby',
        'personalized_summary': 'An important chapter in my life: Became an aunt when my sister had her first baby',
        'categories': ['family', 'love'],
        'transcript': 'When they placed little Emma in my arms for the first time, I was overwhelmed with love and protectiveness. She was so tiny and perfect. Watching my sister become a mother was incredible - seeing her strength and natural instincts. I never knew I could love someone so much so instantly.',
        'prompt': 'Share a meaningful family memory',
        'date': DateTime(2016, 3, 22).toIso8601String(),
        'type': 'recording',
      },
      
      // 2015 - Health challenges
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2015,
        'summary': 'Dealt with a health scare that changed my perspective on life',
        'personalized_summary': 'Dealt with a health scare that changed my perspective on life',
        'categories': ['health', 'wisdom'],
        'transcript': 'The doctor said "We need to run more tests" and my world stopped. Waiting for results was agony - I couldn\'t eat, sleep, or focus on anything. Thankfully it was benign, but those two weeks taught me not to take my health for granted and to live more fully in the present.',
        'prompt': 'Share something about your health journey',
        'date': DateTime(2015, 11, 8).toIso8601String(),
        'type': 'recording',
      },
      
      // 2014 - Adventures
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2014,
        'summary': 'Climbed Mount Washington despite being afraid of heights',
        'personalized_summary': 'Reflecting on when I climbed Mount Washington despite being afraid of heights - it shaped who I am today',
        'categories': ['adventure', 'growth'],
        'transcript': 'I\'ve always been terrified of heights, but something about that mountain called to me. The hike was brutal - my legs were shaking, and I wanted to turn back multiple times. But reaching the summit and seeing that view... I felt like I could do anything. It taught me that courage isn\'t the absence of fear.',
        'prompt': 'Share a moment when you felt truly accomplished',
        'date': DateTime(2014, 7, 12).toIso8601String(),
        'type': 'recording',
      },
      
      // 2013 - Career beginnings
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2013,
        'summary': 'Started my first real job and learned about professional life',
        'personalized_summary': 'Started my first real job and learned about professional life',
        'categories': ['career', 'growth'],
        'transcript': 'My first day at the office was terrifying and exciting. I had no idea what I was doing, and everyone seemed so confident and professional. I made mistakes, asked lots of questions, and slowly found my footing. It was the beginning of understanding what I wanted from my career.',
        'prompt': 'Tell me about your work or career journey',
        'date': DateTime(2013, 6, 3).toIso8601String(),
        'type': 'recording',
      },
      
      // 2012 - Education
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2012,
        'summary': 'Studied abroad in Spain and became fluent in Spanish',
        'personalized_summary': 'A meaningful time when I studied abroad in Spain and became fluent in Spanish',
        'categories': ['education', 'adventure'],
        'transcript': 'Living with the Rodriguez family in Sevilla was life-changing. They barely spoke English, so I had to learn Spanish quickly. At first I was frustrated and embarrassed by my mistakes, but they were so patient and encouraging. By the end of the semester, I was dreaming in Spanish!',
        'prompt': 'Tell me about your learning experiences',
        'date': DateTime(2012, 9, 20).toIso8601String(),
        'type': 'recording',
      },
      
      // 2011 - Friendships
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2011,
        'summary': 'Met my best friend during freshman year of college',
        'personalized_summary': 'An important chapter in my life: Met my best friend during freshman year of college',
        'categories': ['friends', 'love'],
        'transcript': 'I was homesick and lonely during my first weeks at college. Then I met Jamie in the library - we were both stressed about the same chemistry exam. We started studying together, and before I knew it, we were inseparable. Thirteen years later, she\'s still my closest friend.',
        'prompt': 'Describe a special friendship',
        'date': DateTime(2011, 9, 10).toIso8601String(),
        'type': 'recording',
      },
      
      // 2010 - Coming of age
      {
        'profile_id': profileId,
        'uuid': _uuid.v4(),
        'year': 2010,
        'summary': 'Graduated high school and felt excited but scared about the future',
        'personalized_summary': 'Graduated high school and felt excited but scared about the future',
        'categories': ['education', 'growth'],
        'transcript': 'High school graduation felt surreal. I was excited about college and independence, but also terrified about leaving home and everything familiar. The ceremony was long and boring, but when they called my name, I felt this mix of pride and nervousness about what came next.',
        'prompt': 'Describe what was happening in your life then',
        'date': DateTime(2010, 6, 15).toIso8601String(),
        'type': 'recording',
      },
    ];
  }
}