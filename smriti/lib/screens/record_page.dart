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
import '../storage/archive_utils.dart';

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
  const RecordPage({required this.prompt, required this.profileId, Key? key}) : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcription = '';
  String? _audioPath;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
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

  Future<void> _stopRecording() async {
    final path = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _audioPath = path;
    });
    if (path != null) {
      await _transcribeAudio(File(path));
      // Save to archive after transcription
      if (_audioPath != null && _transcription.isNotEmpty) {
        await saveToArchive(
          audioFile: File(_audioPath!),
          transcript: _transcription,
          prompt: widget.prompt,
          date: DateTime.now(),
          profileId: widget.profileId,
          metadata: {
            'prompt': widget.prompt,
            'date': DateTime.now().toIso8601String(),
          },
        );
      }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
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
                    : Text(
                        _transcription.isEmpty
                            ? 'Transcription will appear here...'
                            : _transcription,
                        style: AppTextStyles.body.copyWith(fontSize: 16),
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