import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  final Map<String, double> predictions;
  final double confidence;
  final double quality;

  PredictionResult({
    required this.predictions,
    required this.confidence,
    required this.quality,
  });
}

class Classifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  static const double confidenceThreshold = 0.05;
  static const int ttaIterations = 4;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      options.threads = 4;
      
      _interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite', options: options);
      
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('Model loaded. Input Shape: $inputShape, Output Shape: $outputShape');

      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => l.split(' ').skip(1).join(' ').trim())
          .toList();
      
      debugPrint('Loaded ${_labels.length} labels: $_labels');
      debugPrint('Expected output classes: ${outputShape.length > 1 ? outputShape[1] : 'unknown'}');
      
      if (outputShape.length > 1 && outputShape[1] != _labels.length) {
        debugPrint('WARNING: Model output classes (${outputShape[1]}) does not match labels count (${_labels.length})');
        debugPrint('This will cause prediction misalignment!');
      }
    } catch (e) {
      debugPrint('Error loading model or labels: $e');
      rethrow;
    }
  }

  Future<PredictionResult> classify(File imageFile) async {
    if (_interpreter == null) {
      await loadModel();
    }
    
    if (_labels.isEmpty) {
      throw Exception('Labels not loaded properly');
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      
      final augmentedInputs = await compute(_preprocessImageWithTTA, imageBytes);
      
      final allPredictions = <Map<String, double>>[];
      for (final input in augmentedInputs) {
        final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
        _interpreter!.run(input, output);
        
        final outputList = output[0] as List<double>;
        debugPrint('Raw model output: $outputList');
        
        // Check if output is already probabilities (sum ~ 1.0 and all positive)
        double sum = outputList.fold(0.0, (a, b) => a + b);
        bool isProbabilities = sum > 0.9 && sum < 1.1 && outputList.every((x) => x >= 0 && x <= 1);
        
        List<double> finalOutput;
        if (isProbabilities) {
           finalOutput = outputList;
        } else {
           finalOutput = _softmax(outputList);
        }
        
        // Sharpen the predictions to boost confidence of the top class
        // Temperature < 1.0 makes it sharper (higher confidence for top class)
        finalOutput = _sharpen(finalOutput, 0.3);
        
        debugPrint('Final output: $finalOutput');
        
        final pred = <String, double>{};
        for (var i = 0; i < _labels.length && i < finalOutput.length; i++) {
          pred[_labels[i]] = finalOutput[i] * 100;
        }
        
        // Ensure predictions sum to exactly 100%
        final total = pred.values.fold(0.0, (a, b) => a + b);
        if (total > 0) {
          final normalizedPred = <String, double>{};
          pred.forEach((key, value) {
            normalizedPred[key] = (value / total) * 100;
          });
          debugPrint('Normalized predictions: $normalizedPred');
          allPredictions.add(normalizedPred);
        } else {
          allPredictions.add(pred);
        }
      }
      
      var aggregated = _aggregatePredictions(allPredictions);

      // Sharpen aggregated predictions to boost confidence of the winner
      if (aggregated.isNotEmpty) {
        final keys = aggregated.keys.toList();
        final values = aggregated.values.toList();
        final sharpenedValues = _sharpen(values, 0.2);
        aggregated = Map.fromIterables(keys, sharpenedValues.map((e) => e * 100));
      }
      
      final topPrediction = aggregated.isNotEmpty ? aggregated.entries.first : null;
      final confidence = topPrediction != null ? topPrediction.value / 100 : 0.0;
      final quality = _calculatePredictionQuality(aggregated);
      
      final filtered = _filterPredictionsByConfidence(aggregated);
      
      return PredictionResult(
        predictions: filtered,
        confidence: confidence,
        quality: quality,
      );
    } catch (e) {
      debugPrint('Classification error: $e');
      throw Exception('Classification failed: $e');
    }
  }

  Map<String, double> _aggregatePredictions(List<Map<String, double>> allPredictions) {
    if (allPredictions.isEmpty) {
      return {};
    }
    final aggregated = <String, double>{};
    for (final pred in allPredictions) {
      for (final entry in pred.entries) {
        aggregated[entry.key] = (aggregated[entry.key] ?? 0) + entry.value;
      }
    }
    for (final key in aggregated.keys) {
      aggregated[key] = aggregated[key]! / allPredictions.length;
    }
    return Map.fromEntries(
      aggregated.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
  }

  Map<String, double> _filterPredictionsByConfidence(Map<String, double> predictions) {
    return Map.fromEntries(
      predictions.entries
          .where((e) => e.value / 100 >= confidenceThreshold)
          .toList()
    );
  }

  double _calculatePredictionQuality(Map<String, double> predictions) {
    final sorted = predictions.entries.toList();
    if (sorted.isEmpty) return 0.0;
    
    final topConfidence = sorted[0].value / 100;
    final secondConfidence = sorted.length > 1 ? sorted[1].value / 100 : 0.0;
    final confidence = topConfidence;
    final separation = (topConfidence - secondConfidence);
    final entropy = _calculateEntropy(predictions.values.toList());
    
    final qualityScore = (confidence * 0.5) + (separation * 0.3) + ((1 - entropy) * 0.2);
    return qualityScore.clamp(0.0, 1.0);
  }

  double _calculateEntropy(List<double> probabilities) {
    double entropy = 0.0;
    for (final prob in probabilities) {
      final p = prob / 100;
      if (p > 0) {
        entropy -= p * math.log(p) / math.log(2);
      }
    }
    final maxEntropy = math.log(_labels.length) / math.log(2);
    return maxEntropy > 0 ? entropy / maxEntropy : 0.0;
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  List<double> _sharpen(List<double> probs, double temperature) {
    final exponent = 1.0 / temperature;
    final powered = probs.map((x) => math.pow(x, exponent)).toList();
    final sum = powered.reduce((a, b) => a + b);
    return powered.map((x) => (x / sum).toDouble()).toList();
  }

  void dispose() {
    _interpreter?.close();
  }
}


List<Uint8List> _preprocessImageWithTTA(List<int> imageBytes) {
  var image = img.decodeImage(Uint8List.fromList(imageBytes));
  
  if (image == null) {
    throw Exception('Could not decode image');
  }

  // Orientation is now handled by FlutterImageCompress before this
  
  final inputs = <Uint8List>[];
  
  for (int i = 0; i < Classifier.ttaIterations; i++) {
    var augmented = _augmentImage(image, i);
    final processed = _preprocessImage(augmented, 224);
    final input = _imageToByteListFloat32(processed, 224);
    inputs.add(input);
  }
  
  return inputs;
}

img.Image _augmentImage(img.Image image, int iteration) {
  switch (iteration) {
    case 0:
      return image;
    case 1:
      return img.copyRotate(image, 90);
    case 2:
      return img.copyRotate(image, 180);
    case 3:
      return img.copyRotate(image, 270);
    default:
      return image;
  }
}

img.Image _preprocessImage(img.Image image, int targetSize) {
  // Ensure minimum size
  if (image.width < 100 || image.height < 100) {
    image = img.copyResize(image, width: math.max(image.width, 224), height: math.max(image.height, 224));
  }
  
  // Center crop to square
  final size = math.min(image.width, image.height);
  final x = (image.width - size) ~/ 2;
  final y = (image.height - size) ~/ 2;
  final cropped = img.copyCrop(image, x, y, size, size);
  
  // Resize to target size with proper interpolation
  return img.copyResize(cropped, width: targetSize, height: targetSize, interpolation: img.Interpolation.cubic);
}

Uint8List _imageToByteListFloat32(img.Image image, int inputSize) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      
      // Standard Teachable Machine normalization [-1, 1]
      buffer[pixelIndex++] = (img.getRed(pixel) - 127.5) / 127.5;
      buffer[pixelIndex++] = (img.getGreen(pixel) - 127.5) / 127.5;
      buffer[pixelIndex++] = (img.getBlue(pixel) - 127.5) / 127.5;
    }
  }
  return convertedBytes.buffer.asUint8List();
}
