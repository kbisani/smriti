import 'package:flutter/material.dart';
import 'screens/profile_selection.dart';
import 'screens/home.dart';
import 'screens/record.dart';
import 'screens/timeline.dart';
import 'screens/archive.dart';

void main() {
  runApp(SmritiApp());
}

class SmritiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smriti',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (context) => ProfileSelectionPage(),
        '/home': (context) => HomePage(),
        '/record': (context) => RecordPage(),
        '/timeline': (context) => TimelinePage(),
        '/archive': (context) => ArchivePage(),
      },
    );
  }
}
