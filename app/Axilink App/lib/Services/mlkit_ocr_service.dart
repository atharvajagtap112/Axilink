import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:path_provider/path_provider.dart';

/// On-device OCR using Google ML Kit Text Recognition.
///
/// Drop-in replacement for the previous AzureVisionService: it exposes the same
/// callbacks and [extractTextFromImage] entry point so existing widgets keep
/// working. Unlike Azure, this runs entirely on-device (Android/iOS), needs no
/// API key, and returns synchronously with no submit/poll round-trip.
class MlkitOcrService {
  // Callbacks (match the old AzureVisionService surface)
  Function(String text)? onTextExtracted;
  Function(List<TextRegion> regions)? onRegionsDetected;
  Function(String error)? onError;

  final mlkit.TextRecognizer _recognizer =
      mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

  /// Extract text from raw (encoded) image bytes, e.g. a JPEG/PNG screenshot.
  ///
  /// ML Kit needs an [InputImage]; for arbitrary encoded bytes the reliable
  /// path is to write a temp file and use [InputImage.fromFilePath].
  Future<OcrResult?> extractTextFromImage(Uint8List imageBytes) async {
    File? tempFile;
    try {
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final inputImage = mlkit.InputImage.fromFilePath(tempFile.path);
      final recognized = await _recognizer.processImage(inputImage);

      final result = OcrResult.fromRecognizedText(recognized);

      if (result.text.isNotEmpty) {
        onTextExtracted?.call(result.text);
        onRegionsDetected?.call(result.regions);
      }

      return result;
    } catch (e) {
      final error = 'OCR error: $e';
      onError?.call(error);
      print('[MlkitOcr] $error');
      return null;
    } finally {
      // Best-effort cleanup of the temp file.
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  /// Release native resources. Call from the owning widget's dispose().
  void dispose() {
    _recognizer.close();
  }
}

/// OCR Result model. Kept API-compatible with the old Azure result so callers
/// that read `.text` and `.regions` need no changes.
class OcrResult {
  final String language;
  final List<TextRegion> regions;
  final String text;
  final double? confidence;

  OcrResult({
    required this.language,
    required this.regions,
    required this.text,
    this.confidence,
  });

  /// Build a result from ML Kit's RecognizedText.
  factory OcrResult.fromRecognizedText(mlkit.RecognizedText recognized) {
    final regions = <TextRegion>[];

    for (final block in recognized.blocks) {
      final lines = <TextLine>[];

      for (final line in block.lines) {
        final words = <TextWord>[];
        for (final element in line.elements) {
          words.add(TextWord(
            boundingBox: _rectToString(element.boundingBox),
            text: element.text,
          ));
        }
        lines.add(TextLine(
          boundingBox: _rectToString(line.boundingBox),
          words: words,
          text: line.text,
        ));
      }

      regions.add(TextRegion(
        boundingBox: _rectToString(block.boundingBox),
        lines: lines,
        text: block.text,
      ));
    }

    return OcrResult(
      language: 'en',
      regions: regions,
      text: recognized.text.trim(),
    );
  }

  static String _rectToString(Rect r) {
    // left,top,width,height — matches the comma-joined format used before.
    return '${r.left.toInt()},${r.top.toInt()},'
        '${r.width.toInt()},${r.height.toInt()}';
  }
}

/// Text region (maps to an ML Kit text block).
class TextRegion {
  final String boundingBox;
  final List<TextLine> lines;
  final String text;

  TextRegion({
    required this.boundingBox,
    required this.lines,
    required this.text,
  });
}

/// Text line with words.
class TextLine {
  final String boundingBox;
  final List<TextWord> words;
  final String text;

  TextLine({
    required this.boundingBox,
    required this.words,
    required this.text,
  });
}

/// Individual word.
class TextWord {
  final String boundingBox;
  final String text;
  final double? confidence;

  TextWord({
    required this.boundingBox,
    required this.text,
    this.confidence,
  });
}
