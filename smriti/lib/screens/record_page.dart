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
  
  const RecordPage({
    required this.prompt, 
    required this.profileId, 
    this.isStoryContinuation = false,
    this.originalStoryUuid,
    Key? key
  }) : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
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

  @override
  void initState() {
    super.initState();
    _profileService = QdrantProfileService();
    _continuationService = StoryContinuationService(_profileService);
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _transcriptController.dispose();
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
  }

  void _cancelEditTranscript() {
    setState(() {
      _isEditingTranscript = false;
      _editableTranscript = _transcription;
      _transcriptController.text = _transcription;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isStoryContinuation ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Continue Story',
          style: AppTextStyles.headline.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: widget.isStoryContinuation ? 16 : 32),
              Text(
                widget.prompt,
                style: AppTextStyles.body.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isRecording ? 100 : 80,
                  height: _isRecording ? 100 : 80,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isRecording)
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                width: double.infinity,
                child: _isTranscribing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 16),
                          Text('Transcribing...', style: AppTextStyles.body),
                        ],
                      )
                    : _transcription.isEmpty
                        ? Text('Transcription will appear here...', style: AppTextStyles.body.copyWith(fontSize: 16))
                        : _isEditingTranscript
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _transcriptController,
                                    maxLines: 8,
                                    minLines: 3,
                                    onChanged: (val) => _editableTranscript = val,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: EdgeInsets.all(12),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _cancelEditTranscript,
                                        child: Text('Cancel', style: AppTextStyles.label),
                                      ),
                                      SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _saveReviewedTranscript,
                                        child: Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_editableTranscript, style: AppTextStyles.body.copyWith(fontSize: 16)),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => setState(() => _isEditingTranscript = true),
                                        child: Text('Edit'),
                                      ),
                                      SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: _saveReviewedTranscript,
                                        child: Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
              ),
              if (_audioPath != null && !_isRecording && !_isTranscribing)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text('Audio saved: $_audioPath', style: AppTextStyles.label),
                ),
              const Spacer(),
              if (_isRecording)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: _cancelRecording,
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _stopRecording,
                      child: Text('Save'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}