import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/profile_memory.dart';
import '../models/sub_user_profile.dart';

class QdrantService {
  final String baseUrl;
  final String apiKey;

  QdrantService({required this.baseUrl, required this.apiKey});

  // Collection names
  static const String _profilesCollection = 'user_profiles';
  static const String _memoriesCollection = 'profile_memories';
  static const String _eventsCollection = 'profile_events';
  static const String _relationshipsCollection = 'profile_relationships';
  static const String _recordingsCollection = 'profile_recordings';

  /// Initialize all required collections
  Future<void> initializeCollections() async {
    await Future.wait([
      _createCollection(_profilesCollection, 1536), // OpenAI text-embedding-ada-002 dimension
      _createCollection(_memoriesCollection, 1536),
      _createCollection(_eventsCollection, 1536),
      _createCollection(_relationshipsCollection, 1536),
      _createCollection(_recordingsCollection, 1536),
    ]);
    
    // Verify collections exist
    await _verifyCollections();
  }

  /// Verify that all collections exist and are accessible
  Future<void> _verifyCollections() async {
    final collections = [
      _profilesCollection,
      _memoriesCollection,
      _eventsCollection,
      _relationshipsCollection,
      _recordingsCollection,
    ];
    
    for (final collection in collections) {
      try {
        final url = Uri.parse('$baseUrl/collections/$collection');
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'api-key': apiKey,
          },
        );
        
        if (response.statusCode == 200) {
          print('✓ Collection $collection verified and accessible');
        } else {
          print('✗ Collection $collection not accessible: ${response.statusCode}');
        }
      } catch (e) {
        print('✗ Error verifying collection $collection: $e');
      }
    }
  }

  Future<void> _createCollection(String collection, int dimension) async {
    final url = Uri.parse('$baseUrl/collections/$collection');
    final body = jsonEncode({
      'vectors': {
        'size': dimension,
        'distance': 'Cosine'
      }
    });
    
    print('Creating collection: $collection');
    print('Request URL: $url');
    
    try {
      final response = await http.put(
        url,
        body: body,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
      );
      
      print('Collection creation response status: ${response.statusCode}');
      print('Collection creation response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 409) {
        // 409 means collection already exists, which is fine
        print('Collection $collection created/exists, creating indexes...');
        
        // Create indexes for profile_id filtering
        await _createPayloadIndex(collection, 'profile_id', 'keyword');
        await _createPayloadIndex(collection, 'type', 'keyword');
        await _createPayloadIndex(collection, 'uuid', 'keyword');
        
        print('Indexes created for collection: $collection');
      } else {
        throw Exception('Failed to create collection $collection: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error creating collection $collection: $e');
      // Try to create indexes anyway in case collection already exists
      try {
        print('Attempting to create indexes for existing collection...');
        await _createPayloadIndex(collection, 'profile_id', 'keyword');
        await _createPayloadIndex(collection, 'type', 'keyword');
        await _createPayloadIndex(collection, 'uuid', 'keyword');
        print('Indexes created for existing collection: $collection');
      } catch (indexError) {
        print('Could not create indexes for $collection: $indexError');
      }
    }
  }

  Future<void> _createPayloadIndex(String collection, String fieldName, String fieldType) async {
    final url = Uri.parse('$baseUrl/collections/$collection/index');
    final body = jsonEncode({
      'field_name': fieldName,
      'field_schema': {'type': fieldType}
    });
    
    try {
      final response = await http.put(
        url,
        body: body,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
      );
      print('Index $fieldName created for $collection: ${response.statusCode}');
    } catch (e) {
      print('Index creation failed for $fieldName in $collection: $e');
    }
  }

  /// Upsert a user profile
  Future<void> upsertProfile({
    required SubUserProfile profile,
    required List<double> embedding,
  }) async {
    print('Upserting profile to collection: $_profilesCollection');
    await _upsertPoint(
      collection: _profilesCollection,
      id: profile.id,
      embedding: embedding,
      payload: {
        'name': profile.name,
        'initials': profile.initials,
        'relation': profile.relation,
        'language_preference': profile.languagePreference,
        'bio': profile.bio,
        'birth_date': profile.birthDate?.toIso8601String(),
        'birth_place': profile.birthPlace,
        'tags': profile.tags,
        'created_at': profile.createdAt.toIso8601String(),
        'last_interaction_at': profile.lastInteractionAt?.toIso8601String(),
        'archived': profile.archived,
        'type': 'profile'
      },
    );
    print('Profile upserted successfully');
  }

  /// Upsert profile memory
  Future<void> upsertProfileMemory({
    required String profileId,
    required ProfileMemory memory,
    required List<double> embedding,
  }) async {
    await _upsertPoint(
      collection: _memoriesCollection,
      id: profileId,
      embedding: embedding,
      payload: {
        'profile_id': profileId,
        'name': memory.name,
        'birth_year': memory.birthYear,
        'birth_place': memory.birthPlace,
        'type': 'memory'
      },
    );
  }

  /// Upsert an event
  Future<void> upsertEvent({
    required String profileId,
    required String eventId,
    required Map<String, dynamic> eventData,
    required List<double> embedding,
  }) async {
    await _upsertPoint(
      collection: _eventsCollection,
      id: eventId,
      embedding: embedding,
      payload: {
        'profile_id': profileId,
        'year': eventData['year'],
        'event': eventData['event'],
        'uuid': eventData['uuid'],
        'type': 'event',
        ...eventData,
      },
    );
  }

  /// Upsert a relationship
  Future<void> upsertRelationship({
    required String profileId,
    required String relationshipId,
    required Map<String, dynamic> relationshipData,
    required List<double> embedding,
  }) async {
    await _upsertPoint(
      collection: _relationshipsCollection,
      id: relationshipId,
      embedding: embedding,
      payload: {
        'profile_id': profileId,
        'type': 'relationship',
        ...relationshipData,
      },
    );
  }

  /// Upsert a recording with metadata
  Future<void> upsertRecording({
    required String profileId,
    required String recordingId,
    required Map<String, dynamic> metadata,
    required List<double> embedding,
  }) async {
    await _upsertPoint(
      collection: _recordingsCollection,
      id: recordingId,
      embedding: embedding,
      payload: {
        'profile_id': profileId,
        'year': metadata['year'],
        'summary': metadata['summary'],
        'personalized_summary': metadata['personalized_summary'],
        'categories': metadata['categories'],
        'uuid': metadata['uuid'],
        'transcript': metadata['transcript'],
        'prompt': metadata['prompt'],
        'date': metadata['date'],
        'type': 'recording',
        ...metadata,
      },
    );
  }

  /// Generic upsert method
  Future<void> _upsertPoint({
    required String collection,
    required String id,
    required List<double> embedding,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('$baseUrl/collections/$collection/points');
    final body = jsonEncode({
      'points': [
        {
          'id': id,
          'vector': embedding,
          'payload': payload,
        }
      ]
    });
    
    print('Sending upsert request to: $url');
    print('Point ID: $id, Embedding size: ${embedding.length}');
    
    final response = await http.put(
      url,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    
    print('Upsert response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('Upsert failed with response: ${response.body}');
      throw Exception('Failed to upsert $collection: \n${response.body}');
    } else {
      print('Upsert successful for collection: $collection');
    }
  }

  /// Search for similar content across all collections
  Future<List<Map<String, dynamic>>> search({
    required String collection,
    required List<double> embedding,
    int limit = 5,
    Map<String, dynamic>? filter,
  }) async {
    final url = Uri.parse('$baseUrl/collections/$collection/points/search');
    final body = jsonEncode({
      'vector': embedding,
      'limit': limit,
      'with_payload': true,
      if (filter != null) 'filter': filter,
    });
    final response = await http.post(
      url,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search $collection: \n${response.body}');
    }
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['result']);
  }

  /// Search for recordings by profile ID
  Future<List<Map<String, dynamic>>> searchRecordingsByProfile({
    required String profileId,
    required List<double> embedding,
    int limit = 10,
  }) async {
    return search(
      collection: _recordingsCollection,
      embedding: embedding,
      limit: limit,
      filter: {
        'must': [{'key': 'profile_id', 'match': {'value': profileId}}]
      },
    );
  }

  /// Search for events by profile ID
  Future<List<Map<String, dynamic>>> searchEventsByProfile({
    required String profileId,
    required List<double> embedding,
    int limit = 10,
  }) async {
    return search(
      collection: _eventsCollection,
      embedding: embedding,
      limit: limit,
      filter: {
        'must': [{'key': 'profile_id', 'match': {'value': profileId}}]
      },
    );
  }

  /// Get all recordings for a profile (for timeline)
  Future<List<Map<String, dynamic>>> getRecordingsByProfile(String profileId) async {
    final url = Uri.parse('$baseUrl/collections/$_recordingsCollection/points/scroll');
    final body = jsonEncode({
      'filter': {
        'must': [{'key': 'profile_id', 'match': {'value': profileId}}]
      },
      'limit': 1000,
      'with_payload': true,
    });
    final response = await http.post(
      url,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get recordings: \n${response.body}');
    }
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['result']['points']);
  }

  /// Get all events for a profile
  Future<List<Map<String, dynamic>>> getEventsByProfile(String profileId) async {
    final url = Uri.parse('$baseUrl/collections/$_eventsCollection/points/scroll');
    final body = jsonEncode({
      'filter': {
        'must': [{'key': 'profile_id', 'match': {'value': profileId}}]
      },
      'limit': 1000,
      'with_payload': true,
    });
    final response = await http.post(
      url,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get events: \n${response.body}');
    }
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['result']['points']);
  }

  /// Get profile memory
  Future<Map<String, dynamic>?> getProfileMemory(String profileId) async {
    final url = Uri.parse('$baseUrl/collections/$_memoriesCollection/points/$profileId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['result'];
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get profile memory: \n${response.body}');
    }
  }

  /// Delete a point by ID
  Future<void> deletePoint(String collection, String id) async {
    print('DEBUG Delete: Attempting to delete $id from $collection');
    final url = Uri.parse('$baseUrl/collections/$collection/points/delete');
    final body = jsonEncode({
      'points': [id]
    });
    final response = await http.post(
      url,
      body: body,
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
      },
    );
    print('DEBUG Delete: Response status: ${response.statusCode}, body: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete from $collection: \n${response.body}');
    } else {
      print('DEBUG Delete: Successfully deleted $id from $collection');
    }
  }

  /// Delete event by UUID
  Future<void> deleteEventByUuid(String uuid) async {
    await deletePoint(_eventsCollection, uuid);
  }

  /// Delete recording by UUID
  Future<void> deleteRecordingByUuid(String uuid) async {
    await deletePoint(_recordingsCollection, uuid);
  }

  /// Delete profile by profile ID
  Future<void> deleteProfileById(String profileId) async {
    await deletePoint(_profilesCollection, profileId);
  }

  /// Delete points by filter across collections (excluding profiles collection)
  Future<void> deletePointsByFilter(Map<String, dynamic> filter) async {
    final collections = [
      _memoriesCollection,
      _eventsCollection,
      _relationshipsCollection,
      _recordingsCollection,
    ];

    for (final collection in collections) {
      try {
        final url = Uri.parse('$baseUrl/collections/$collection/points/delete');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'api-key': apiKey,
          },
          body: jsonEncode({
            'filter': filter,
          }),
        );

        if (response.statusCode != 200) {
          print('Warning: Failed to delete points from $collection: ${response.body}');
        } else {
          print('Successfully deleted points from $collection');
        }
      } catch (e) {
        print('Error deleting points from $collection: $e');
      }
    }
  }

}

/// Example usage:
///
/// final qdrant = QdrantService(
///   baseUrl: 'https://your-qdrant-url.com',
///   apiKey: '<YOUR_API_KEY>',
/// );
///
/// // Initialize collections
/// await qdrant.initializeCollections();
///
/// // Upsert a profile
/// await qdrant.upsertProfile(
///   profile: userProfile,
///   embedding: await qdrant.generateEmbedding(userProfile.name + ' ' + (userProfile.bio ?? '')),
/// );
///
/// // Search for similar recordings
/// final results = await qdrant.searchRecordingsByProfile(
///   profileId: 'profile-id',
///   embedding: queryEmbedding,
/// ); 