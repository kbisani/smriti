import 'package:flutter/material.dart';
import '../theme.dart';
import 'dart:async';

class RecordPage extends StatefulWidget {
  final String prompt;
  const RecordPage({required this.prompt, Key? key}) : super(key: key);

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool _isRecording = false;
  String _transcription = '';
  late final List<String> _dummyWords;
  int _dummyIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dummyWords = [
      'This', 'is', 'a', 'live', 'transcription', 'demo.',
      'Imagine', 'your', 'words', 'appearing', 'here', 'in', 'real', 'time!'
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _transcription = '';
      _dummyIndex = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (_isRecording && _dummyIndex < _dummyWords.length) {
        setState(() {
          _transcription += (_transcription.isEmpty ? '' : ' ') + _dummyWords[_dummyIndex];
          _dummyIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _timer?.cancel();
  }

  void _cancelRecording() {
    setState(() {
      _isRecording = false;
      _transcription = '';
      _dummyIndex = 0;
    });
    _timer?.cancel();
    Navigator.of(context).pop();
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
                child: Text(
                  _transcription.isEmpty ? 'Live transcription will appear here...' : _transcription,
                  style: AppTextStyles.body.copyWith(fontSize: 16),
                ),
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