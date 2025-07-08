import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/profile.dart';
import 'models/main_user.dart';
import 'storage/main_user_storage.dart';
import 'screens/profile_selection.dart';
import 'screens/main_user_onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Register adapters if using Hive type adapters for Profile/MainUser
  // Hive.registerAdapter(ProfileAdapter());
  // Hive.registerAdapter(MainUserAdapter());
  runApp(SmritiApp());
}

class SmritiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smriti',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: _RootPage(),
    );
  }
}

class _RootPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MainUser?>(
      future: MainUserStorage().getMainUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          // No main user, show onboarding
          return MainUserOnboardingPage();
        }
        // Main user exists, show profile selection
        return ProfileSelectionPage();
      },
    );
  }
}
