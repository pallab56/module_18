import 'package:flutter/material.dart';
import 'package:newapp/location_tracker_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Location Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const LocationTrackerScreen(),
    );
  }
}

