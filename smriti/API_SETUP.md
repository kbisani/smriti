# API Setup Guide

## OpenRouter API Configuration

This app uses OpenAI Whisper through OpenRouter for speech-to-text transcription.

### Setup Steps:

1. **Get an OpenRouter API Key:**
   - Go to https://openrouter.ai/keys
   - Sign up or log in
   - Create a new API key

2. **Create Environment File:**
   - Create a `.env` file in the root directory of this project
   - Add your API key:
   ```
   OPENROUTER_API_KEY=your_actual_api_key_here
   ```

3. **Usage:**
   - The app will automatically use the Whisper model for transcription
   - Audio files are sent to OpenRouter's API endpoint
   - Results are returned as plain text

### API Details:
- **Endpoint:** `https://openrouter.ai/api/v1/audio/transcriptions`
- **Model:** `openai/whisper-1`
- **Format:** Multipart form data with audio file
- **Response:** JSON with transcribed text

### Cost:
- OpenRouter charges based on usage
- Whisper-1 is typically very cost-effective
- Check https://openrouter.ai/pricing for current rates

### Security:
- Never commit your `.env` file to version control
- The `.env` file is already in `.gitignore`
- Keep your API key secure and private 