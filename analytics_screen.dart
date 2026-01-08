import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('analytics')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No analytics data available.'),
            );
          }

          final analytics = snapshot.data!.docs;
          final classificationData = _getClassificationData(analytics);
          final stats = _getStats(analytics);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCards(stats),
                const SizedBox(height: 20),
                _buildClassificationChart(classificationData),
                const SizedBox(height: 20),
                _buildRecentActivity(analytics),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(Map<String, int> stats) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt, size: 32, color: Colors.green),
                  const SizedBox(height: 8),
                  Text('${stats['classifications'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Classifications'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.launch, size: 32, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text('${stats['app_opens'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('App Opens'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationChart(Map<String, int> data) {
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No classification data available'),
        ),
      );
    }

    final total = data.values.fold(0, (a, b) => a + b);
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.pink];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Most Classified Leaves', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...() {
              final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return sortedEntries.map((entry) {
                final percentage = ((entry.value / total) * 100).toStringAsFixed(1);
                final index = sortedEntries.indexOf(entry);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors[index % colors.length].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors[index % colors.length].withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors[index % colors.length],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...analytics.take(5).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final event = data['event'] ?? 'Unknown';
              final timestamp = data['timestamp'] as Timestamp?;
              
              return ListTile(
                leading: _getEventIcon(event),
                title: Text(_getEventTitle(event, data)),
                subtitle: Text(_getEventSubtitle(event, data)),
                trailing: timestamp != null
                    ? Text('${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}')
                    : null,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Map<String, int> _getClassificationData(List<QueryDocumentSnapshot> analytics) {
    final Map<String, int> classificationCounts = {};
    
    for (final doc in analytics) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['event'] == 'leaf_classified') {
        final className = data['className'] ?? 'Unknown';
        classificationCounts[className] = (classificationCounts[className] ?? 0) + 1;
      }
    }
    
    return classificationCounts;
  }

  Map<String, int> _getStats(List<QueryDocumentSnapshot> analytics) {
    int classifications = 0;
    int appOpens = 0;
    
    for (final doc in analytics) {
      final data = doc.data() as Map<String, dynamic>;
      final event = data['event'] ?? '';
      
      if (event == 'leaf_classified') classifications++;
      if (event == 'app_opened') appOpens++;
    }
    
    return {
      'classifications': classifications,
      'app_opens': appOpens,
    };
  }

  Icon _getEventIcon(String event) {
    switch (event) {
      case 'leaf_classified':
        return const Icon(Icons.camera_alt, color: Colors.green);
      case 'app_opened':
        return const Icon(Icons.launch, color: Colors.blue);
      case 'error':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.analytics, color: Colors.grey);
    }
  }

  String _getEventTitle(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'leaf_classified':
        return 'Leaf Classified: ${data['className'] ?? 'Unknown'}';
      case 'app_opened':
        return 'App Opened';
      case 'error':
        return 'Error Occurred';
      default:
        return event;
    }
  }

  String _getEventSubtitle(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'leaf_classified':
        final confidence = data['confidence'] ?? 0.0;
        final source = data['imageSource'] ?? 'unknown';
        return 'Confidence: ${(confidence * 100).toStringAsFixed(1)}% • Source: $source';
      case 'app_opened':
        return 'User opened the application';
      case 'error':
        return data['error'] ?? 'Unknown error';
      default:
        return 'Analytics event';
    }
  }
}