import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmbeddingService {
  static const String _openaiEndpoint = 'https://api.openai.com/v1/embeddings';

  /// Generate embeddings using OpenAI's text-embedding-ada-002 model
  static Future<List<double>> generateEmbedding(String text) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY not found in environment variables');
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      'model': 'text-embedding-ada-002',
      'input': text,
    });

    try {
      final response = await http.post(
        Uri.parse(_openaiEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embedding = List<double>.from(data['data'][0]['embedding']);
        return embedding;
      } else {
        throw Exception('Failed to generate embedding: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating embedding: $e');
    }
  }

  /// Generate embeddings for profile data
  static Future<List<double>> generateProfileEmbedding({
    required String name,
    String? bio,
    String? birthPlace,
    List<String>? tags,
  }) async {
    final textComponents = [
      name,
      if (bio != null && bio.isNotEmpty) bio,
      if (birthPlace != null && birthPlace.isNotEmpty) birthPlace,
      if (tags != null && tags.isNotEmpty) tags.join(' '),
    ];
    
    final combinedText = textComponents.join(' ');
    return generateEmbedding(combinedText);
  }

  /// Generate embeddings for memory data
  static Future<List<double>> generateMemoryEmbedding({
    String? name,
    String? birthPlace,
    List<Map<String, dynamic>>? events,
    List<Map<String, dynamic>>? relationships,
  }) async {
    final textComponents = <String>[];
    
    if (name != null && name.isNotEmpty) textComponents.add(name);
    if (birthPlace != null && birthPlace.isNotEmpty) textComponents.add(birthPlace);
    
    if (events != null) {
      for (final event in events) {
        final eventText = event['event']?.toString();
        if (eventText != null && eventText.isNotEmpty) {
          textComponents.add(eventText);
        }
      }
    }
    
    if (relationships != null) {
      for (final rel in relationships) {
        final relText = rel.toString();
        textComponents.add(relText);
      }
    }
    
    final combinedText = textComponents.join(' ');
    return generateEmbedding(combinedText.isEmpty ? 'empty memory' : combinedText);
  }

  /// Generate embeddings for event data
  static Future<List<double>> generateEventEmbedding({
    required String event,
    int? year,
  }) async {
    final text = year != null ? '$year: $event' : event;
    return generateEmbedding(text);
  }

  /// Generate embeddings for recording metadata
  static Future<List<double>> generateRecordingEmbedding({
    required String transcript,
    String? summary,
    String? personalizedSummary,
    List<String>? categories,
  }) async {
    final textComponents = [
      transcript,
      if (summary != null && summary.isNotEmpty) summary,
      if (personalizedSummary != null && personalizedSummary.isNotEmpty) personalizedSummary,
      if (categories != null && categories.isNotEmpty) categories.join(' '),
    ];
    
    final combinedText = textComponents.join(' ');
    return generateEmbedding(combinedText);
  }
}