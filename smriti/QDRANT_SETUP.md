# Qdrant Integration Setup Guide

This guide explains how to set up Qdrant vector database integration for your Smriti app.

## Overview

The app has been migrated from JSON-based storage (memory.json, meta.json) to use Qdrant vector database for:
- Profile data storage with semantic search
- Memory and event storage with embeddings
- Recording metadata with vector search capabilities
- Timeline data retrieval
- Mosaic view categorization

## Environment Variables

Add the following variables to your `.env` file:

```env
# Qdrant Configuration
QDRANT_URL=https://your-qdrant-cluster-url.com
QDRANT_API_KEY=your-qdrant-api-key

# OpenAI (required for embeddings and AI features)
OPENAI_API_KEY=your-openai-api-key
```

## Qdrant Collections

The app creates and manages these collections automatically:

1. **user_profiles** - Stores user profile data with embeddings
2. **profile_memories** - Stores consolidated memory data per profile
3. **profile_events** - Individual events with year and description
4. **profile_relationships** - Relationship data (future use)
5. **profile_recordings** - Recording metadata with transcripts

## Migration Process

### Automatic Migration
When you first run the app with Qdrant configured:

1. The `QdrantProfileService` will initialize collections
2. Existing JSON data can be migrated using a migration script (see below)
3. New recordings will automatically use Qdrant storage

### Manual Migration Script
Create a migration script to transfer existing JSON data:

```dart
// Example migration code (create as a separate script)
Future<void> migrateExistingData() async {
  final profileService = QdrantProfileService();
  await profileService.initialize();
  
  // Get all existing profiles
  final profiles = await SubUserProfileStorage().getAllProfiles();
  
  for (final profile in profiles) {
    // Migrate profile
    await profileService.storeProfile(profile);
    
    // Migrate memory data
    final memory = await readProfileMemory(profile.id); // old method
    await profileService.storeProfileMemory(profile.id, memory);
    
    // Migrate existing recordings from archive folder
    // ... (implement based on your archive structure)
  }
}
```

## Key Changes Made

### Files Modified:
- `lib/storage/qdrant_service.dart` - Enhanced with comprehensive methods
- `lib/storage/qdrant_profile_service.dart` - New service layer
- `lib/storage/embedding_service.dart` - New embedding generation service
- `lib/screens/timeline.dart` - Updated to use Qdrant data
- `lib/screens/add_profile_page.dart` - Updated profile creation
- `lib/screens/record_page.dart` - Updated recording storage
- `lib/screens/archive.dart` - Updated deletion methods

### New Features:
- Vector-based semantic search for memories
- Automatic embedding generation for all content
- Scalable storage that doesn't rely on local file system
- Real-time memory updates with AI-powered fact extraction
- Category-based content organization for mosaic view

## API Usage Examples

### Search Similar Memories
```dart
final results = await profileService.searchSimilarContent(
  profileId: 'user-profile-id',
  query: 'childhood memories about school',
  limit: 5,
);
```

### Get Timeline Data
```dart
final timelineData = await profileService.getTimelineData(profileId);
// Returns Map<int, List<Map<String, dynamic>>> grouped by year
```

### Get Mosaic Data
```dart
final mosaicData = await profileService.getMosaicData(profileId);
// Returns Map<String, List<Map<String, dynamic>>> grouped by category
```

## Testing

1. Verify environment variables are loaded:
   ```dart
   print('Qdrant URL: ${dotenv.env['QDRANT_URL']}');
   ```

2. Test collection initialization:
   ```dart
   final service = QdrantProfileService();
   await service.initialize(); // Should create collections
   ```

3. Test profile storage and retrieval:
   ```dart
   await service.storeProfile(testProfile);
   final memory = await service.getProfileMemory(testProfile.id);
   ```

## Troubleshooting

### Common Issues:

1. **Collection creation fails**
   - Check Qdrant URL and API key
   - Ensure Qdrant cluster is running
   - Verify network connectivity

2. **Embedding generation fails**
   - Check OpenAI API key
   - Verify API quota and billing
   - Check for rate limiting

3. **Data not appearing in timeline/mosaic**
   - Ensure recordings have proper metadata
   - Check that embeddings are generated successfully
   - Verify collection names match

### Debug Commands:
```dart
// Print current memory
final memory = await _profileService.getProfileMemory(profileId);
print(memory.toJsonString());

// Search recordings
final recordings = await _qdrant.getRecordingsByProfile(profileId);
print('Found ${recordings.length} recordings');
```

## Performance Considerations

- Embeddings are generated asynchronously
- Large amounts of historical data may take time to migrate
- Consider batching operations for better performance
- Vector searches are optimized for semantic similarity

## Future Enhancements

- Relationship extraction and storage
- Advanced query capabilities
- Real-time synchronization
- Backup and restore functionality
- Analytics and insights based on vector data