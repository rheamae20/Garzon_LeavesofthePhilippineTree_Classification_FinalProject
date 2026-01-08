import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/homepage_screen.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    AnalyticsService.trackAppOpen();
    // Initialize sample data if analytics collection is empty
    _initializeAnalyticsIfEmpty();
    return MaterialApp(
      title: 'Philippine Tree Leaves',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomepageScreen(),
    );
  }

  void _initializeAnalyticsIfEmpty() async {
    final snapshot = await FirebaseFirestore.instance.collection('analytics').limit(1).get();
    if (snapshot.docs.isEmpty) {
      await AnalyticsService.initializeSampleData();
    }
  }
}


