import 'dart:convert';
import 'dart:typed_data';

import 'package:air_pointer/Services/azure_config.dart';
import 'package:http/http.dart' as http;

/// Improved Azure Computer Vision Service using Read API (better accuracy)
class AzureVisionService {
  // Callbacks
  Function(String text)? onTextExtracted;
  Function(List<TextRegion> regions)? onRegionsDetected;
  Function(String error)? onError;
  
  /// Extract text using the READ API (much better accuracy than OCR API)
  /// This is an async operation - submit then poll for results
  Future<OcrResult? > extractTextFromImage(Uint8List imageBytes) async {
    try {
      print('[AzureVision] Sending image for Read API analysis...');
      
      // Step 1: Submit the image for analysis
      final submitResponse = await http.post(
        Uri.parse('${AzureConfig.visionEndpoint}/vision/v3.2/read/analyze'),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureConfig.visionKey,
          'Content-Type':  'application/octet-stream',
        },
        body:  imageBytes,
      );
      
      print('[AzureVision] Submit Response status: ${submitResponse.statusCode}');
      
      if (submitResponse.statusCode != 202) {
        final error = 'Read API submit failed: ${submitResponse.statusCode} - ${submitResponse.body}';
        onError?.call(error);
        return null;
      }
      
      // Step 2: Get the operation location from headers
      final operationLocation = submitResponse.headers['operation-location'];
      if (operationLocation == null) {
        onError?.call('No operation location returned');
        return null;
      }
      
      // Step 3: Poll for results
      return await _pollForResults(operationLocation);
      
    } catch (e) {
      final error = 'OCR error: $e';
      onError?.call(error);
      print('[AzureVision] $error');
      return null;
    }
  }
  
  /// Poll the Read API for results
  Future<OcrResult?> _pollForResults(String operationLocation) async {
    const maxAttempts = 10;
    const delayMs = 1000;
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(const Duration(milliseconds: delayMs));
      
      final response = await http.get(
        Uri.parse(operationLocation),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureConfig.visionKey,
        },
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final status = jsonResponse['status'];
        
        print('[AzureVision] Read status: $status (attempt ${attempt + 1})');
        
        if (status == 'succeeded') {
          final result = OcrResult.fromReadApiJson(jsonResponse);
          
          if (result.text.isNotEmpty) {
            onTextExtracted?.call(result.text);
            onRegionsDetected?.call(result.regions);
          }
          
          return result;
        } else if (status == 'failed') {
          onError?.call('Read API analysis failed');
          return null;
        }
        // If 'running' or 'notStarted', continue polling
      }
    }
    
    onError?.call('Read API timed out');
    return null;
  }
  
  /// Fallback to legacy OCR API (faster but less accurate)
  Future<OcrResult?> extractTextLegacy(Uint8List imageBytes) async {
    try {
      final response = await http.post(
        Uri.parse('${AzureConfig.visionEndpoint}/vision/v3.2/ocr? language=en&detectOrientation=true'),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureConfig. visionKey,
          'Content-Type': 'application/octet-stream',
        },
        body: imageBytes,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return OcrResult.fromLegacyJson(jsonResponse);
      }
      
      return null;
    } catch (e) {
      print('[AzureVision] Legacy OCR error: $e');
      return null;
    }
  }
}

/// OCR Result model - supports both Read API and legacy OCR API
class OcrResult {
  final String language;
  final List<TextRegion> regions;
  final String text;
  final double?  confidence;
  
  OcrResult({
    required this.language,
    required this.regions,
    required this.text,
    this.confidence,
  });
  
  /// Parse Read API response (better accuracy)
  factory OcrResult.fromReadApiJson(Map<String, dynamic> json) {
    final regions = <TextRegion>[];
    final textBuffer = StringBuffer();
    double totalConfidence = 0;
    int wordCount = 0;
    
    final analyzeResult = json['analyzeResult'];
    if (analyzeResult != null && analyzeResult['readResults'] != null) {
      for (final page in analyzeResult['readResults']) {
        for (final line in page['lines'] ??  []) {
          final words = <TextWord>[];
          final lineText = line['text'] ?? '';
          
          for (final word in line['words'] ?? []) {
            final confidence = (word['confidence'] ?? 0.0).toDouble();
            totalConfidence += confidence;
            wordCount++;
            
            words.add(TextWord(
              boundingBox: _boundingBoxToString(word['boundingBox']),
              text: word['text'] ?? '',
              confidence: confidence,
            ));
          }
          
          regions.add(TextRegion(
            boundingBox: _boundingBoxToString(line['boundingBox']),
            lines: [TextLine(
              boundingBox: _boundingBoxToString(line['boundingBox']),
              words: words,
              text: lineText,
            )],
            text: lineText,
          ));
          
          textBuffer.writeln(lineText);
        }
      }
    }
    
    return OcrResult(
      language: analyzeResult? ['language'] ?? 'en',
      regions: regions,
      text: textBuffer.toString().trim(),
      confidence: wordCount > 0 ? totalConfidence / wordCount : null,
    );
  }
  
  /// Parse legacy OCR API response
  factory OcrResult.fromLegacyJson(Map<String, dynamic> json) {
    final regions = <TextRegion>[];
    final textBuffer = StringBuffer();
    
    if (json['regions'] != null) {
      for (final region in json['regions']) {
        final textRegion = TextRegion. fromJson(region);
        regions.add(textRegion);
        textBuffer.writeln(textRegion.text);
      }
    }
    
    return OcrResult(
      language:  json['language'] ?? 'en',
      regions: regions,
      text: textBuffer.toString().trim(),
    );
  }
  
  static String _boundingBoxToString(dynamic bbox) {
    if (bbox == null) return '';
    if (bbox is String) return bbox;
    if (bbox is List) return bbox.join(',');
    return '';
  }
}

/// Text region with bounding box
class TextRegion {
  final String boundingBox;
  final List<TextLine> lines;
  final String text;
  
  TextRegion({
    required this.boundingBox,
    required this. lines,
    required this.text,
  });
  
  factory TextRegion.fromJson(Map<String, dynamic> json) {
    final lines = <TextLine>[];
    final textBuffer = StringBuffer();
    
    if (json['lines'] != null) {
      for (final line in json['lines']) {
        final textLine = TextLine.fromJson(line);
        lines.add(textLine);
        textBuffer.writeln(textLine. text);
      }
    }
    
    return TextRegion(
      boundingBox: json['boundingBox'] ?? '',
      lines: lines,
      text: textBuffer.toString().trim(),
    );
  }
}

/// Text line with words
class TextLine {
  final String boundingBox;
  final List<TextWord> words;
  final String text;
  
  TextLine({
    required this.boundingBox,
    required this. words,
    required this.text,
  });
  
  factory TextLine.fromJson(Map<String, dynamic> json) {
    final words = <TextWord>[];
    final textBuffer = StringBuffer();
    
    if (json['words'] != null) {
      for (final word in json['words']) {
        final textWord = TextWord.fromJson(word);
        words.add(textWord);
        textBuffer.write('${textWord.text} ');
      }
    }
    
    return TextLine(
      boundingBox: json['boundingBox'] ?? '',
      words: words,
      text: textBuffer.toString().trim(),
    );
  }
}

/// Individual word with confidence score
class TextWord {
  final String boundingBox;
  final String text;
  final double?  confidence;
  
  TextWord({
    required this.boundingBox,
    required this.text,
    this.confidence,
  });
  
  factory TextWord.fromJson(Map<String, dynamic> json) {
    return TextWord(
      boundingBox: json['boundingBox'] ?? '',
      text: json['text'] ?? '',
      confidence:  json['confidence']?.toDouble(),
    );
  }
}