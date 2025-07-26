import 'package:flutter/material.dart';
import '../theme.dart';
import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import '../storage/qdrant_profile_service.dart';
import '../storage/embedding_service.dart';
import '../storage/story_continuation_service.dart';
import 'package:uuid/uuid.dart';
import '../storage/qdrant_service.dart';

// Use EmbeddingService.generateEmbedding instead

class OpenAIWhisperService {
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get endpoint => 'https://api.openai.com/v1/audio/transcriptions';

  Future<String> transcribe(File audioFile, {String languageCode = 'en'}) async {
    final audioBytes = await audioFile.readAsBytes();

    // Create multipart request for file upload
    final request = http.MultipartRequest('POST', Uri.parse(endpoint));

    // Add headers
    request.headers['Authorization'] = 'Bearer $apiKey';

    // Add the audio file
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      ),
    );

    // Add form fields
    request.fields['model'] = 'whisper-1';
    request.fields['language'] = languageCode;
    request.fields['response_format'] = 'json';

    try {
      print('Sending request to: $endpoint');
      print('API Key: ${apiKey.isNotEmpty ? 'Present' : 'Missing'}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? '[No transcription result]';
      } else {
        return '[Transcription failed: ${response.statusCode}] - ${response.body}';
      }
    } catch (e) {
      print('Exception: $e');
      return '[Transcription error: $e]';
    }
  }
}

class RecordPage extends StatefulWidget {
  final String prompt;
  final String profileId;
  final bool isStoryContinuation;
  final String? originalStoryUuid;
  final Map<String, dynamic>? storyContext;
  
  const RecordPage({
    required this.prompt, 
    required this.profileId, 
    this.isStoryContinuation = false,
    this.originalStoryUuid,
    this.storyContext,
    Key? key
  }) : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcription = '';
  String? _audioPath;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String _editableTranscript = '';
  bool _isEditingTranscript = false;
  final TextEditingController _transcriptController = TextEditingController();
  String? _archiveDirPath; // Track the archive directory for this recording
  String? _recordingUuid; // Track the uuid for this recording
  late final QdrantProfileService _profileService;
  late final StoryContinuationService _continuationService;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _profileService = QdrantProfileService();
    _continuationService = StoryContinuationService(_profileService);
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _initRecorder();
    
    // Start fade animation if this is a story continuation
    if (widget.isStoryContinuation) {
      _fadeController.forward();
    }
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _transcriptController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/recorded_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
    );
    setState(() {
      _isRecording = true;
      _transcription = '';
      _audioPath = filePath;
    });
  }

  Future<Map<String, dynamic>?> _extractMetadataWithOpenAI(String transcript) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final endpoint = 'https://api.openai.com/v1/chat/completions';
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final systemPrompt =
        'Extract the year (if any), main categories (choose from: love, family, career, wisdom, friends, education, health, adventure, loss, growth), and a 1-sentence summary no longer than 20 words from this story. Respond ONLY in minified JSON with keys: year, categories, summary.';
    final body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': transcript},
      ],
      'max_tokens': 128,
      'temperature': 0.3,
    });
    try {
      final response = await http.post(Uri.parse(endpoint), headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        // Try to parse the returned JSON
        return jsonDecode(content);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _audioPath = path;
    });
    if (path != null) {
      await _transcribeAudio(File(path));
      // Generate UUID for this recording
      _recordingUuid = const Uuid().v4();
      // NOTE: Do not save to database here - wait for user to review transcript
    }
  }

  void _cancelRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _transcription = '';
      _audioPath = null;
    });
    Navigator.of(context).pop();
  }

  Future<void> _transcribeAudio(File audioFile) async {
    setState(() {
      _isTranscribing = true;
      _transcription = '';
    });
    final sttService = OpenAIWhisperService();
    final result = await sttService.transcribe(audioFile, languageCode: 'en');
    setState(() {
      _isTranscribing = false;
      _transcription = result;
      _editableTranscript = result;
      _transcriptController.text = result;
      _isEditingTranscript = false;
    });
  }

  Future<void> _saveReviewedTranscript() async {
    // Extract metadata from transcript
    Map<String, dynamic>? metadata;
    if (_editableTranscript.isNotEmpty) {
      metadata = await _extractMetadataWithOpenAI(_editableTranscript);
    }
    
    // Save to archive after review
    if (_audioPath != null && _editableTranscript.isNotEmpty) {
      // Ensure uuid is present in metadata
      if (metadata != null) {
        metadata['uuid'] = _recordingUuid;
      }
      
      // Handle story continuation vs new story for reviewed transcript
      if (widget.isStoryContinuation && widget.originalStoryUuid != null) {
        // This is a continuation of an existing story
        await _continuationService.appendToStory(
          profileId: widget.profileId,
          originalStoryUuid: widget.originalStoryUuid!,
          continuationTranscript: _editableTranscript,
          continuationPrompt: widget.prompt,
          continuationMetadata: metadata,
        );
      } else {
        // This is a new story
        // Ensure prompt and essential fields are always included
        final fullMetadata = {
          'prompt': widget.prompt,
          'date': DateTime.now().toIso8601String(),
          'uuid': _recordingUuid,
          if (metadata != null) ...metadata, // Merge OpenAI extracted metadata
        };
        
        await _profileService.updateProfileMemoryWithStory(
          profileId: widget.profileId,
          metadata: fullMetadata,
          transcript: _editableTranscript,
        );
      }
      
      // Save audio file to local storage
      _archiveDirPath = await _profileService.saveAudioToArchive(
        audioFile: File(_audioPath!),
        profileId: widget.profileId,
        recordingId: _recordingUuid ?? const Uuid().v4(),
      );
    }
    
    setState(() {
      _isEditingTranscript = false;
      _editableTranscript = '';
      _transcription = '';
      _audioPath = null;
      _archiveDirPath = null;
      _recordingUuid = null;
    });
    
    // Return success result to parent page
    if (mounted) {
      Navigator.of(context).pop('success');
    }
  }

  void _cancelEditTranscript() {
    setState(() {
      _isEditingTranscript = false;
      _editableTranscript = _transcription;
      _transcriptController.text = _transcription;
    });
  }

  Widget _buildStoryContext() {
    if (!widget.isStoryContinuation || widget.storyContext == null) {
      return const SizedBox.shrink();
    }

    final storyParts = widget.storyContext!['story_parts'] as List<dynamic>? ?? [];
    final recentSessions = storyParts.take(3).toList(); // Show last 3 sessions
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Story So Far',
              style: AppTextStyles.label.copyWith(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...recentSessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              final transcript = session['transcript'] ?? '';
              final isRecent = index == recentSessions.length - 1;
              
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 100)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRecent 
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.card.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: isRecent 
                        ? Border.all(color: AppColors.primary.withOpacity(0.3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRecent ? AppColors.primary : AppColors.textSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRecent ? 'Latest' : 'Session ${index + 1}',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        transcript.length > 100 
                            ? '${transcript.substring(0, 100)}...'
                            : transcript,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: isRecent 
                              ? AppColors.textPrimary 
                              : AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            if (storyParts.length > 3)
              Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '+ ${storyParts.length - 3} more sessions',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                child: Column(
                  children: [
                    // Story context for continuations
                    _buildStoryContext(),
                    
                    // Prompt section
                    _buildPromptSection(),
                    
                    const SizedBox(height: 32),
                    
                    // Recording button
                    _buildRecordingButton(),
                    
                    const SizedBox(height: 32),
                    
                    // Transcription section
                    _buildTranscriptionSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    _buildActionButtons(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.isStoryContinuation ? 'Continue Story' : 'New Memory',
            style: AppTextStyles.body.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.isStoryContinuation)
            Text(
              'Adding to existing story',
              style: AppTextStyles.label.copyWith(fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildPromptSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(height: 16),
          Text(
            widget.prompt,
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isRecording ? 120 : 100,
        height: _isRecording ? 120 : 100,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : AppColors.primary).withOpacity(0.3),
              blurRadius: _isRecording ? 30 : 20,
              spreadRadius: _isRecording ? 8 : 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: _isRecording ? 48 : 40,
            ),
            const SizedBox(height: 4),
            Text(
              _isRecording ? 'Stop' : 'Record',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _transcription.isEmpty && !_isTranscribing
            ? _buildEmptyState()
            : _isTranscribing
                ? _buildTranscribingState()
                : _isEditingTranscript
                    ? _buildEditingState()
                    : _buildReadyState(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Your story will appear here after recording',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Converting your voice to text...',
            style: AppTextStyles.body.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment',
            style: AppTextStyles.label,
          ),
        ],
      ),
    );
  }

  Widget _buildEditingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Edit your story',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _transcriptController,
            maxLines: 6,
            onChanged: (val) => _editableTranscript = val,
            style: AppTextStyles.body.copyWith(height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(16),
              hintText: 'Your story...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Your story',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _editableTranscript,
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isRecording) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelRecording,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _stopRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Finish',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_transcription.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Row(
          children: [
            if (!_isEditingTranscript) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isEditingTranscript = true),
                  icon: Icon(Icons.edit_rounded, size: 18),
                  label: Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isEditingTranscript ? _saveReviewedTranscript : _saveReviewedTranscript,
                icon: Icon(
                  _isEditingTranscript ? Icons.check_rounded : Icons.bookmark_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _isEditingTranscript ? 'Save Changes' : 'Save Memory',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_isEditingTranscript) ...[
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEditTranscript,
                  child: Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}