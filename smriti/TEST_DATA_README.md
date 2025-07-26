# Test Data for Smriti App

This document explains the comprehensive test data system created for testing all features of the Smriti memory app.

## 🚀 Quick Start

The easiest way to import test data is through the app itself:

1. Open the app
2. Go to the **Profile** tab (tap the profile icon in the bottom navigation)
3. Scroll down to the **Developer Tools** section
4. Tap **"Import Test Data (20+ memories)"**
5. Confirm the import in the dialog
6. Wait 30-60 seconds for the import to complete

## 📊 What Test Data Includes

### Memory Distribution
- **20+ diverse memories** spanning 2010-2024
- **Multi-session stories** with continuation examples
- **Emotional variety**: positive, challenging, neutral, and reflective memories
- **All 10 categories** represented: love, family, career, wisdom, friends, education, health, adventure, loss, growth

### Timeline Features Testing
- **Year-based filtering**: Memories distributed across 15 years
- **Session count filtering**: Mix of single and multi-session stories
- **Visual timeline**: Chronological flow with varied content
- **Birth event integration**: Profile birth year automatically added

### Graph Visualizations Testing
- **Memory Network Graph**: 
  - Time-based clustering (memories grouped by decades/proximity)
  - Session count indicators
  - Interactive navigation to story details
- **Emotional Landscape**:
  - Sentiment analysis with keyword detection
  - Color-coded emotional indicators (green=positive, orange=reflective, blue=neutral)
  - Smooth curve visualization showing emotional journey over time
  - Custom painted timeline with interactive points

### Archive Features Testing
- **Grid/List view modes**: Different display formats
- **Search functionality**: Searchable transcripts and summaries
- **Category filtering**: All 10 categories with stories
- **Date range filtering**: Recent, monthly, yearly filters
- **AI summary display**: Both regular and personalized summaries

### Story Continuation Testing
- **Multi-session story example**: Home renovation project with 3 sessions
  - Session 1: Starting the renovation (excitement)
  - Session 2: Hitting challenges (struggle)
  - Session 3: Successful completion (accomplishment)
- **Proper continuation linking**: Original story UUID references
- **Session count tracking**: Accurate session numbers

## 📋 Detailed Memory List

### 2024 (Recent Achievements)
- **Tech Career Start**: Landing dream job after preparation
- **Dog Adoption**: Rescue dog bringing joy and companionship

### 2023 (Mixed Emotions & Growth)
- **Grandmother's Passing**: Peaceful loss with beautiful memories
- **First Marathon**: 8-month training culminating in achievement
- **Home Renovation** (3-session story):
  - Starting the project with excitement
  - Facing major challenges and setbacks
  - Successful completion and celebration

### 2022 (Challenges & Reconnection)
- **Financial Difficulties**: Learning budgeting lessons during tough times
- **High School Reunion**: Reconnecting with childhood friends

### 2021 (Pandemic Era)
- **Learning Guitar**: Discovering new passion during lockdown
- **Job Loss**: Company downsizing leading to better opportunities

### 2020 (Life Changes)
- **Pandemic Wedding**: Small backyard ceremony adaptation

### 2019 (Growth & Adventure)
- **Southeast Asia Travel**: Backpacking and cultural discovery
- **Starting Therapy**: Working through mental health challenges

### 2018 (Educational Milestones)
- **College Graduation**: Graduating with honors after hard work

### 2017 (Relationship Growth)
- **Relationship End**: Learning from a meaningful breakup

### 2016 (Family Expansion)
- **Becoming an Aunt**: Sister's first baby bringing new love

### 2015 (Health Perspective)
- **Health Scare**: Medical uncertainty changing life perspective

### 2014 (Personal Achievement)
- **Mountain Climbing**: Overcoming fear of heights

### 2013 (Career Beginning)
- **First Job**: Learning professional life basics

### 2012 (International Experience)
- **Study Abroad**: Becoming fluent in Spanish in Sevilla

### 2011 (Friendship Formation)
- **College Best Friend**: Meeting lifelong friend in library

### 2010 (Coming of Age)
- **High School Graduation**: Excited but nervous about the future

## 🔍 Testing Scenarios

### Timeline Tab Testing
1. **Year Filtering**: Use the filter to view specific years (2020, 2023, etc.)
2. **Session Filtering**: Filter to show only multi-session stories
3. **Navigation**: Tap on stories to view detailed session breakdowns
4. **Empty States**: Clear all filters to test empty state handling

### Graph Tab Testing
1. **Network View**: 
   - View memory clusters grouped by time periods
   - Check decade-based grouping (2010s, 2020s)
   - Test navigation from memory nodes to full stories
2. **Emotional Landscape**:
   - Observe sentiment analysis color coding
   - Check emotional curve visualization
   - Verify year labels on timeline points
   - Test positive vs. challenging memory detection

### Archive Testing
1. **View Modes**: Switch between grid and list views
2. **Search**: Search for terms like "guitar", "marathon", "home", "job"
3. **Category Filters**: Test each of the 10 categories
4. **Date Filters**: Use "This Year", "This Month" filters
5. **AI Summaries**: Check both regular and personalized summary display

### Mosaic Tab Testing
1. **Category Distribution**: Each category should have multiple stories
2. **Story Navigation**: Tap category tiles to view stories within categories
3. **Session Indicators**: Multi-session stories should show session counts

## 🛠 Advanced Usage

### Manual Data Import (Developer)
If you need to import data programmatically:

```dart
import 'package:your_app/utils/test_data_importer.dart';
import 'package:your_app/storage/qdrant_profile_service.dart';

final profileService = QdrantProfileService();
final importer = TestDataImporter(profileService);
await importer.importTestData('your-profile-id');
```

### Data Structure
Each memory includes:
- **UUID**: Unique identifier
- **Year**: For timeline organization
- **Summary**: Display text
- **Personalized Summary**: AI-enhanced version
- **Categories**: 1-3 category tags
- **Transcript**: Full conversation text
- **Prompt**: Original question that elicited the memory
- **Emotional Content**: Varied sentiment for testing analysis

### Continuation Stories
The home renovation story demonstrates:
- **Original Story**: Base memory with session_count: 3
- **Continuations**: Related memories with original_story_uuid reference
- **Proper Linking**: UI shows combined session view

## 🔧 Troubleshooting

### Import Fails
- Ensure Qdrant service is running and accessible
- Check network connectivity
- Verify API keys are properly configured
- Try importing in smaller batches if timeout occurs

### Missing Data
- Check that profile ID matches exactly
- Verify Qdrant collections are properly initialized
- Look for error messages in debug console

### Performance Issues
- Test data includes 20+ memories with full transcripts
- Initial loading may take a few seconds
- Consider implementing pagination for very large datasets

## 🎯 Feature Coverage

This test data comprehensively tests:

✅ **Timeline Visualization**: Year-based organization, filtering, navigation  
✅ **Graph Analysis**: Memory clustering, emotional sentiment, interactive exploration  
✅ **Archive Management**: Search, filtering, multiple view modes  
✅ **Story Continuations**: Multi-session stories, proper linking  
✅ **Emotional Analysis**: Sentiment detection, color coding, timeline visualization  
✅ **Category Organization**: All 10 categories with meaningful distribution  
✅ **Data Persistence**: Qdrant integration, embedding generation  
✅ **UI/UX Features**: Empty states, loading states, navigation flows  

## 📈 Next Steps

After importing test data:

1. **Explore Timeline**: Test all three tabs (Timeline, Graph, Mosaic)
2. **Try Filters**: Use year, session, and category filters
3. **Test Search**: Search across transcripts and summaries in Archive
4. **View Sessions**: Tap multi-session stories to see detailed breakdowns
5. **Analyze Emotions**: Switch between Network and Emotional views in Graph tab
6. **Test Navigation**: Ensure smooth transitions between all features

The test data is designed to showcase the full potential of the Smriti app's memory visualization and exploration capabilities!