import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/leaf_class.dart';
import '../services/classifier.dart' show Classifier, PredictionResult;
import '../services/analytics_service.dart';
import 'analytics_screen.dart';
import '../services/firestore_service.dart';


class CameraScreen extends StatefulWidget {
  final LeafClass? selectedClass;

  const CameraScreen({super.key, this.selectedClass});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final Classifier _classifier = Classifier();
  File? _image;
  bool _isUploading = false;
  bool _isPickingImage = false;
  String? _error;
  double _uploadProgress = 0.0;
  PredictionResult? _predictionResult;
  bool _scanComplete = false;

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      setState(() {
        _error = null;
        _predictionResult = null;
        _scanComplete = false;
      });

      final picked = await _picker.pickImage(source: source);
      _isPickingImage = false;
      
      if (picked == null) return;

      // Preprocess image for classification (fix orientation and resize)
      File imageFileForClassification = File(picked.path);
      try {
        final tmpDir = Directory.systemTemp;
        final targetPath = '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_cls.jpg';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          picked.path,
          targetPath,
          quality: 90,
          minWidth: 1024,
          minHeight: 1024,
          autoCorrectionAngle: true,
        );
        if (compressed != null) {
          imageFileForClassification = File(compressed.path);
        }
      } catch (e) {
        debugPrint('Error preprocessing image: $e');
      }

      setState(() {
        _image = imageFileForClassification;
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      setState(() => _uploadProgress = 0.2);

      final predictionResult = await _classifier.classify(imageFileForClassification);

      setState(() {
        _uploadProgress = 0.5;
        _predictionResult = predictionResult;
      });

      // Compress for upload (smaller size)
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFileForClassification.path,
        '${picked.path}_upload.jpg',
        quality: 40,
        minWidth: 600,
        minHeight: 600,
        autoCorrectionAngle: true,
      );

      setState(() => _uploadProgress = 0.7);

      final fileToUpload = compressedFile != null ? File(compressedFile.path) : imageFileForClassification;
      final bytes = await fileToUpload.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() => _uploadProgress = 0.9);

      await FirestoreService.saveClassification(
        imageData: base64Image,
        fileName: picked.name,
        predictions: predictionResult.predictions,
        confidence: predictionResult.confidence,
        quality: predictionResult.quality,
        classId: widget.selectedClass?.id,
        className: widget.selectedClass?.name,
      );

      // Track analytics
      final topPrediction = predictionResult.predictions.entries.isNotEmpty 
          ? predictionResult.predictions.entries.first 
          : null;
      if (topPrediction != null) {
        AnalyticsService.trackClassification(
          className: topPrediction.key,
          confidence: topPrediction.value / 100,
          imageSource: source == ImageSource.camera ? 'camera' : 'gallery',
        );
      }

      setState(() {
        _isUploading = false;
        _scanComplete = true;
      });
    } catch (e) {
      AnalyticsService.trackError(e.toString(), 'image_classification');
      _isPickingImage = false;
      setState(() {
        _error = 'Classification failed: ${e.toString().split('\n').first}';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedClass?.name ?? 'Classify Leaf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_scanComplete && widget.selectedClass != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (widget.selectedClass!.imageData.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(widget.selectedClass!.imageData),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedClass!.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              widget.selectedClass!.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _image == null
                  ? const Center(child: Text('Select an image to classify'))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_image!, fit: BoxFit.cover, width: double.infinity),
                    ),
            ),
            const SizedBox(height: 16),
            if (_isUploading)
              Column(
                children: [
                  CircularProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('${(_uploadProgress * 100).toInt()}%'),
                ],
              ),
            if (_predictionResult != null && !_isUploading)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.eco, color: Colors.green.shade700, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Classification Results',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'AI-powered leaf identification',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Main prediction message
                      if (_predictionResult!.predictions.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade50, Colors.green.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Identification Complete!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.selectedClass != null && 
                                _predictionResult!.predictions.entries.first.key.toLowerCase() != widget.selectedClass!.name.toLowerCase()
                                  ? 'This is not ${widget.selectedClass!.name.toUpperCase()}. Based on the analysis, this appears to be a ${_predictionResult!.predictions.entries.first.key.toUpperCase()} leaf with ${_predictionResult!.predictions.entries.first.value.toStringAsFixed(1)}% confidence.'
                                  : 'Based on the leaf image analysis, this appears to be a ${_predictionResult!.predictions.entries.first.key.toUpperCase()} leaf with ${_predictionResult!.predictions.entries.first.value.toStringAsFixed(1)}% confidence.',
                                style: TextStyle(
                                  color: widget.selectedClass != null && 
                                  _predictionResult!.predictions.entries.first.key.toLowerCase() != widget.selectedClass!.name.toLowerCase()
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Quality metrics
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.psychology, color: Colors.blue.shade600, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Confidence',
                                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${(_predictionResult!.confidence * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.blue.shade800, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.high_quality, color: Colors.orange.shade600, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quality',
                                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${(_predictionResult!.quality * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: Colors.orange.shade800, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Detailed predictions
                      Text(
                        'Detailed Analysis:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_predictionResult!.predictions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange.shade600),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Unable to identify this leaf with sufficient confidence. Please try with a clearer image or different angle.',
                                  style: TextStyle(color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._predictionResult!.predictions.entries.take(5).map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        e.key.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getConfidenceColor(e.value),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${e.value.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: e.value / 100,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation(_getConfidenceColor(e.value)),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            if (!_scanComplete)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                        );
                      },
                      icon: const Icon(Icons.analytics),
                      label: const Text('Analytics'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _scanComplete = false;
                          _image = null;
                          _predictionResult = null;
                          _error = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
