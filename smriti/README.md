# Smriti

A Flutter app for voice recording and transcription using OpenAI Whisper.

## Features

- Voice recording with real-time feedback
- Speech-to-text transcription using OpenAI Whisper
- Clean, modern UI design
- Cross-platform support (iOS, Android, Web, Desktop)

## Setup

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure API:**
   - Create a `.env` file in the root directory
   - Add your OpenRouter API key:
   ```
   OPENROUTER_API_KEY=your_api_key_here
   ```
   - Get your API key from [OpenRouter](https://openrouter.ai/keys)

3. **Run the App:**
   ```bash
   flutter run
   ```

## API Configuration

This app uses OpenAI Whisper through OpenRouter for speech-to-text transcription. See `API_SETUP.md` for detailed setup instructions.

## Dependencies

- Flutter Sound: Audio recording
- HTTP: API communication
- Flutter Dotenv: Environment variable management
- Hive: Local data storage
