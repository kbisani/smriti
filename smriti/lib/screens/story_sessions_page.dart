import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../theme.dart';

class StorySessionsPage extends StatefulWidget {
  final Map<String, dynamic> storyData;
  final String profileName;

  const StorySessionsPage({
    required this.storyData,
    required this.profileName,
    Key? key,
  }) : super(key: key);

  @override
  State<StorySessionsPage> createState() => _StorySessionsPageState();
}

class _StorySessionsPageState extends State<StorySessionsPage> {
  String? _consolidatedSummary;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _generateConsolidatedSummary();
  }

  Future<void> _generateConsolidatedSummary() async {
    setState(() {
      _loadingSummary = true;
    });

    try {
      final sessions = widget.storyData['sessions'] as List<Map<String, dynamic>>? ?? [];
      final allTranscripts = sessions.asMap().entries.map((entry) {
        final index = entry.key;
        final session = entry.value;
        return '--- Session ${index + 1} ---\n\n${session['transcript'] ?? ''}';
      }).join('\n\n');
      
      final summary = await _generateAISummary(allTranscripts);
      setState(() {
        _consolidatedSummary = summary;
        _loadingSummary = false;
      });
    } catch (e) {
      print('Error generating consolidated summary: $e');
      setState(() {
        _consolidatedSummary = 'Unable to generate summary at this time.';
        _loadingSummary = false;
      });
    }
  }

  Future<String> _generateAISummary(String allTranscripts) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final endpoint = 'https://api.openai.com/v1/chat/completions';
    
    final systemPrompt = '''
You are an expert at creating thoughtful, cohesive summaries of personal stories that span multiple recording sessions.

Create a flowing narrative summary that:
1. Combines all sessions into one coherent story
2. Highlights the progression and development across sessions
3. Maintains the personal, emotional tone
4. Is 2-3 paragraphs maximum
5. Feels like a complete, rich story rather than separate fragments

Focus on the journey, growth, and key details that make this story meaningful.
''';

    final userPrompt = '''
This is a multi-session story from ${widget.profileName}. Please create a thoughtful summary that weaves all sessions together:

$allTranscripts

Create a cohesive narrative summary of this complete story.
''';

    try {
      final requestBody = {
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': 300,
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Date unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.storyData['sessions'] as List<Map<String, dynamic>>? ?? [];
    final originalPrompt = widget.storyData['original_prompt'] ?? '';
    final year = widget.storyData['year'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Story Sessions', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Story Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_stories, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          originalPrompt.isNotEmpty ? originalPrompt : 'Story',
                          style: AppTextStyles.headline.copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (year != null) ...[
                        Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$year', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.video_library, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${sessions.length} sessions', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI-Generated Consolidated Summary
            Text('Complete Story Summary', style: AppTextStyles.headline.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _loadingSummary
                  ? Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text('Generating summary...', style: AppTextStyles.body),
                      ],
                    )
                  : Text(
                      _consolidatedSummary ?? 'No summary available',
                      style: AppTextStyles.body.copyWith(fontSize: 16, height: 1.5),
                    ),
            ),
            
            const SizedBox(height: 32),
            
            // Individual Sessions
            Text('Recording Sessions', style: AppTextStyles.headline.copyWith(fontSize: 16)),
            const SizedBox(height: 16),
            
            ...sessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              final transcript = session['transcript'] ?? '';
              final prompt = session['prompt'] ?? '';
              final date = session['date'] ?? '';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Session ${index + 1}',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(date),
                              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        if (prompt.isNotEmpty && index > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prompt:',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(prompt, style: AppTextStyles.body.copyWith(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Transcript:',
                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          transcript.isNotEmpty ? transcript : 'No transcript available',
                          style: AppTextStyles.body.copyWith(fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}