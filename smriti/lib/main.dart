import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/profile.dart';
import 'models/main_user.dart';
import 'models/sub_user_profile.dart';
import 'storage/main_user_storage.dart';
import 'storage/sub_user_profile_storage.dart';
import 'screens/profile_selection.dart';
import 'screens/add_profile_page.dart';
import 'dart:async';
import 'theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print('Loaded .env: ${dotenv.env}');
  print('API KEY: ${dotenv.env['OPENROUTER_API_KEY']}');

  await Hive.initFlutter();
  runApp(SmritiApp());
}

class SmritiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smriti',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: AppTextStyles.body.fontFamily,
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.headline.copyWith(fontSize: 36),
          headlineMedium: AppTextStyles.headline.copyWith(fontSize: 28),
          headlineSmall: AppTextStyles.headline.copyWith(fontSize: 22),
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.body.copyWith(fontSize: 14),
          labelLarge: AppTextStyles.label,
        ),
      ),
      home: _SplashRootPage(),
    );
  }
}

class _SplashRootPage extends StatefulWidget {
  @override
  State<_SplashRootPage> createState() => _SplashRootPageState();
}

class _SplashRootPageState extends State<_SplashRootPage> with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  MainUser? _mainUser;
  bool _autoCreatedProfile = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _initApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 1));
    _mainUser = await MainUserStorage().getMainUser();
    print('[main.dart] Main user loaded: ${_mainUser?.name}');

    // If main user exists, check if we need to create their profile card
    if (_mainUser != null) {
      await _ensureMainUserProfileExists();
      // Add a short delay to ensure Hive flushes to disk
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (mounted) {
      print('[main.dart] Hiding splash and building main UI');
      setState(() {
        _showSplash = false;
      });
      _controller.forward();
    }
  }

  Future<void> _ensureMainUserProfileExists() async {
    final profileStorage = SubUserProfileStorage();
    final existingProfiles = await profileStorage.getProfiles();
    print('[main.dart] Found ${existingProfiles.length} existing profiles');

    if (existingProfiles.isEmpty) {
      print('[main.dart] No profiles found, creating profile for main user: ${_mainUser!.name}');

      final mainUserProfile = SubUserProfile(
        id: _mainUser!.id,
        name: _mainUser!.name,
        initials: _getInitials(_mainUser!.name),
        relation: 'Your Journal',
        profileImageUrl: _mainUser!.avatarPath,
        languagePreference: 'en',
        birthPlace: '',
        createdAt: _mainUser!.createdAt,
      );

      await profileStorage.addProfile(mainUserProfile);
      print('[main.dart] Successfully created and saved profile card for main user: ${_mainUser!.name}');
      setState(() {
        _autoCreatedProfile = true;
      });
    } else {
      print('[main.dart] Profiles already exist, skipping auto-creation');
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 96, height: 96),
              const SizedBox(height: 24),
              Text(
                'Smriti',
                style: AppTextStyles.headline.copyWith(fontSize: 36),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _mainUser == null ? AddProfilePage(isMainUser: true) : ProfileSelectionPage(),
    );
  }
}