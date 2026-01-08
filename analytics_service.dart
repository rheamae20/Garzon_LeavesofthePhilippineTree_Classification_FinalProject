import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track image classification
  static Future<void> trackClassification({
    required String className,
    required double confidence,
    required String imageSource,
  }) async {
    await _firestore.collection('analytics').add({
      'event': 'leaf_classified',
      'className': className,
      'confidence': confidence,
      'imageSource': imageSource,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Track app usage
  static Future<void> trackAppOpen() async {
    await _firestore.collection('analytics').add({
      'event': 'app_opened',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Track screen views
  static Future<void> trackScreenView(String screenName) async {
    await _firestore.collection('analytics').add({
      'event': 'screen_view',
      'screenName': screenName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Track errors
  static Future<void> trackError(String error, String context) async {
    await _firestore.collection('analytics').add({
      'event': 'error',
      'error': error,
      'context': context,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Initialize sample analytics data
  static Future<void> initializeSampleData() async {
    final sampleData = [
      {
        'event': 'leaf_classified',
        'className': 'mango',
        'confidence': 0.95,
        'imageSource': 'camera',
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'event': 'leaf_classified',
        'className': 'narra',
        'confidence': 0.87,
        'imageSource': 'gallery',
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'event': 'app_opened',
        'timestamp': FieldValue.serverTimestamp(),
      },
    ];

    for (final data in sampleData) {
      await _firestore.collection('analytics').add(data);
    }
  }
}