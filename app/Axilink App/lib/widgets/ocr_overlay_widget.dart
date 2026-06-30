import 'dart:convert';
import 'package:air_pointer/Services/mlkit_ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp.dart';


/// OCR Overlay Widget for extracting text from screen mirror
class OcrOverlayWidget extends StatefulWidget {
  final Uint8List? screenImage;
  final VoidCallback? onClose;
  final StompClient? stompClient;  // ✅ Add STOMP client
  final String? sessionCode;        // ✅ Add session code
  
  const OcrOverlayWidget({
    super.key,
    this.screenImage,
    this.onClose,
    this.stompClient,
    this.sessionCode,
  });
  
  @override
  State<OcrOverlayWidget> createState() => _OcrOverlayWidgetState();
}

class _OcrOverlayWidgetState extends State<OcrOverlayWidget> {
  final MlkitOcrService _visionService = MlkitOcrService();
  
  bool _isProcessing = false;
  String _extractedText = '';
  List<TextRegion> _regions = [];
  String?  _error;
  Uint8List? _highQualityImage;  // ✅ Store high-quality image
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  @override
  void dispose() {
    _visionService.dispose();
    super.dispose();
  }

  void _initializeService() {
    _visionService.onTextExtracted = (text) {
      if (mounted) {
        setState(() {
          _extractedText = text;
          _isProcessing = false;
        });
      }
    };
    
    _visionService.onRegionsDetected = (regions) {
      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
    };
    
    _visionService. onError = (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isProcessing = false;
        });
      }
    };
  }
  
  /// ✅ Request high-quality screenshot from desktop
  Future<void> _requestHighQualityScreenshot() async {
    if (widget.stompClient == null || widget.sessionCode == null) {
      // Fallback to current image
      await _extractTextFromCurrentImage();
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _error = null;
      _extractedText = '';
    });
    
    try {
      // Send request for high-quality screenshot
      widget.stompClient!.send(
        destination: '/app/ocr-screenshot/${widget.sessionCode}',
        body: jsonEncode({
          'quality': 95,  // High quality
          'resize': 1.0,  // Full size
        }),
      );
      
      // Subscribe to response
      widget.stompClient!.subscribe(
        destination: '/topic/ocr-screenshot/${widget.sessionCode}',
        callback: (frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body! );
              if (data['image'] != null) {
                _highQualityImage = base64Decode(data['image']);
                _extractText();
              }
            } catch (e) {
              print('[OCR] Error parsing screenshot: $e');
              setState(() {
                _error = 'Failed to receive screenshot';
                _isProcessing = false;
              });
            }
          }
        },
      );
      
      // Timeout after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_isProcessing && _highQualityImage == null) {
          // Fallback to current image
          _extractTextFromCurrentImage();
        }
      });
      
    } catch (e) {
      print('[OCR] Error requesting screenshot: $e');
      await _extractTextFromCurrentImage();
    }
  }
  
  /// Extract text from current low-quality image (fallback)
  Future<void> _extractTextFromCurrentImage() async {
    if (widget.screenImage == null) {
      setState(() {
        _error = 'No screen image available';
        _isProcessing = false;
      });
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _error = null;
      _extractedText = '';
    });
    
    await _visionService.extractTextFromImage(widget.screenImage!);
  }
  
  /// Extract text using high-quality image
  Future<void> _extractText() async {
    if (_highQualityImage == null) {
      await _extractTextFromCurrentImage();
      return;
    }
    
    await _visionService.extractTextFromImage(_highQualityImage! );
  }
  
  void _copyToClipboard() {
    if (_extractedText. isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _extractedText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Text copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,  // ✅ Limit height
      ),
      decoration: BoxDecoration(
        color: Colors.black. withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(  // ✅ Prevent overflow
                child: Row(
                  children: [
                    Icon(
                      Icons. document_scanner,
                      color:  Colors.purpleAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(  // ✅ Allow text to wrap
                      child: Text(
                        'Text Extraction (OCR)',
                        style:  TextStyle(
                          color:  Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'On-device',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          
          const SizedBox(height: 5),
          
          // ✅ Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Extract button
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _requestHighQualityScreenshot,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.text_fields),
                    label:  Text(_isProcessing ? 'Extracting...' : 'Extract Text from Screen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets. symmetric(vertical: 12),
                    ),
                  ),
                  
                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:  Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red. withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Extracted text
                  if (_extractedText.isNotEmpty) ...[
         
                    Row(
                      mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Extracted Text:',
                          style:  TextStyle(
                            color:  Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${_extractedText.split(' ').length} words',
                              style:  const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.purpleAccent, size: 20),
                              onPressed: _copyToClipboard,
                              tooltip: 'Copy to clipboard',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),  // ✅ Increased height
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius:  BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _extractedText,
                          style:  const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Regions info
                  if (_regions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Found ${_regions.length} text region(s)',
                      style:  const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  
                  // Instructions
                  if (_extractedText.isEmpty && ! _isProcessing && _error == null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border. all(
                          color: Colors.purpleAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child:  const Column(
                        children: [
                          Icon(Icons.info_outline, color: Colors.purpleAccent),
                          SizedBox(height: 8),
                          Text(
                            'Tap "Extract Text" to capture a high-quality\nscreenshot and use on-device ML Kit OCR to\nrecognize and extract all text.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}