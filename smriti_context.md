# Smriti – Development Context

## 🎯 Goal
Smriti is a conversational memoir platform. It enables family members to record and preserve stories through voice/text, then organizes them into interactive timelines and knowledge graphs. It is designed with multilingual support and generational accessibility in mind.

## 💡 Core Concepts
- **Profiles**: Each profile is tied to a relative (e.g., grandfather). Selecting a profile enters their "memory book."
- **Voice-first Recording**: AI-assisted conversational memory capture via mobile app.
- **Knowledge Graph**: Automatically extracted nodes (people, events, places) visualized and linked interactively. Separate from the timeline view — users can switch between views.
- **Contextual Side Notes**: Historical, political, or geographical facts appear as inline footnotes within stories.
- **Timeline View**: Chronologically ordered life events, editable and supplemented by user feedback.
- **Archive View**: Raw data transparency — audio files, transcriptions, and images without AI processing.
- **Time Capsules**: Audio messages intended for future playback (e.g., “for your 18th birthday”).
- **Remote Recording**: Conducted via a joinable link (e.g., like Zoom or Riverside.fm) for recording and transcription.
- **Multilingual Support**: Both original and translated versions of each recording are stored and editable.

## 📱 MVP User Flow

### 1. **Profile Selection Page**
- Grid UI (like Netflix profile selector)
- Each profile is a memory book
- Select → navigate to that person’s memory space

### 2. **Home Page (Memory Book Dashboard)**
- Actions:
  - **Prompt of the Day**: Start a conversation
  - **Dive Deeper**: Follow-up on previous stories
  - **Upload Photos**: Scan or upload + caption
- Bottom Nav: Home | Record | Timeline | Archive
- Top Nav: Profile image | Name | Edit | Settings

### 3. **Record Page**
- Prompt-based recording (new or follow-up)
- Audio + live transcription
- **AI Follow-up Assistant**: Suggests real-time follow-up questions to the *interviewer* during recording (teleprompter-style guidance)
- Save metadata: Date, people mentioned, emotional tone

### 4. **Timeline Page**
- Auto-generated from transcriptions
- Manual override to fix dates
- Interactive map with pins → opens related stories
- **Side Notes**: Inline footnotes for added context on time, location, and history

### 5. **Knowledge Graph View**
- Visual map of nodes (people, places, topics) extracted from stories
- Interactive: tap to expand, see linked stories
- Separate from timeline, accessible via toggle

### 6. **Archive Page**
- Raw data: audio files, images, transcripts
- No AI processing or summarization
- Emphasizes transparency and user ownership

## 🧰 Tech Notes (MVP)
- **Frontend**: Flutter
- **Audio Recording**: Flutter Sound or Just Audio + permission handling
- **Transcription**: Whisper API or Together.ai
- **Storage**: Firebase/Firestore or Supabase
- **Knowledge Graph**: Start with a simple Entity ↔ Event ↔ Time model
- **UI Libraries**: Flutter animations, timeline widgets, graph view
- **Navigation**: Flutter Router or GoRouter

## 🧪 Stretch Features (Post-MVP)
- Time Capsules
- Remote call-based capture
- Search + filtering by emotion, era, or person
- Generative Story Mode (turn nodes into rich narrative)