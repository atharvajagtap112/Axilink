import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp.dart';

class KeyboardScreen extends StatefulWidget {
  final StompClient stompClient;
  final String code;
  const KeyboardScreen({super.key, required this.stompClient,required this.code, required bool isActive});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final String url; 
  bool _isProcessingBackspace = false;
  bool _isClearing = false;



  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
    WidgetsBinding.instance.addObserver(this);
    url='/app/move/${widget.code}';
   
  
      
    
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Re-focus if keyboard tries to close
    if (!_focusNode.hasFocus) {
      _openKeyboard();
    }
  }

  void _openKeyboard() {
    _focusNode.requestFocus();
    // Force keyboard to stay open
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _handleTextChange() {
    if (_isProcessingBackspace || _isClearing) {
      return; // Skip processing if we're handling a backspace or clearing
    }

    final currentText = _controller.text;

    if (currentText.isNotEmpty) {
      // Get the last character typed
      String lastChar = currentText[currentText.length - 1];
      _sendTypingAction(lastChar);
      
      // Clear the text field after sending to prevent accumulation
      _clearTextField();
    }
  }

  void _clearTextField() {
    _isClearing = true;
    _controller.clear();
    // Reset flag after clearing
    Future.delayed(const Duration(milliseconds: 10), () {
      _isClearing = false;
    });
  }

  void _sendTypingAction(String text) {
    if (widget.stompClient.connected) {
      widget.stompClient.send(
        destination: url!,
        body: jsonEncode({"action": "type", "text": text}),
      );
    }
  }

  void _sendBackspaceAction() {
    if (widget.stompClient.connected) {
      widget.stompClient.send(
        destination: url!,
        body: jsonEncode({"action": "backspace"}),
      );
    }
  }

  void _sendEnterAction() {
    if (widget.stompClient.connected) {
      widget.stompClient.send(
        destination: url!,
        body: jsonEncode({"action": "enter"}),
      );
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        // Handle backspace key press
        _isProcessingBackspace = true;
        
        // Just send backspace action - no need to modify text field
        _sendBackspaceAction();
        
        // Reset flag after a short delay
        Future.delayed(const Duration(milliseconds: 50), () {
          _isProcessingBackspace = false;
        });
        
        return true; // Event handled
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Handle enter key press
        _sendEnterAction();
        return true; // Event handled
      }
    }
    return false; // Event not handled
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from closing keyboard
        _openKeyboard();
        return false; // Prevent navigation back
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          _handleKeyEvent(event);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF121212), // Dark background
        
          body: GestureDetector(
            onTap: () {
              // Re-focus when user taps anywhere
              _openKeyboard(); 
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E1E1E),
                    Color(0xFF121212),
                    Color(0xFF0A0A0A),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Main content
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3A3A3A),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_alt_outlined,
                            size: 48,
                            color: const Color(0xFF64B5F6),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Keyboard Active',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Remote keyboard is ready for input',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64B5F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF64B5F6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Tap anywhere to ensure focus',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF64B5F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hidden input field - positioned off-screen but still active
                  Positioned(
                    left: -100,
                    top: -100,
                    child: SizedBox(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        showCursor: false,
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        cursorColor: Colors.transparent,
                     
                        maxLines: null,
                        minLines: 1,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        // Prevent keyboard from closing on certain actions
                        onTap: () {
                          _openKeyboard();
                        },
                        // Handle text submission (Enter key on some keyboards)
                        onSubmitted: (value) {
                          _sendEnterAction();
                          // Keep keyboard open
                          _openKeyboard();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}