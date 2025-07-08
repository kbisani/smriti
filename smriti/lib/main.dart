import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/profile.dart';
import 'models/main_user.dart';
import 'storage/main_user_storage.dart';
import 'screens/profile_selection.dart';
import 'screens/main_user_onboarding_page.dart';
import 'dart:async';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
      _controller.forward();
    }
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
      child: _mainUser == null ? MainUserOnboardingPage() : ProfileSelectionPage(),
    );
  }
}
