import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import '../services/on_device_speech_service.dart';

/// Voice Control Widget for hands-free desktop control
class VoiceControlWidget extends StatefulWidget {
  final StompClient stompClient;
  final String sessionCode;
  final VoidCallback?  onClose;
  
  const VoiceControlWidget({
    super.key,
    required this. stompClient,
    required this.sessionCode,
    this. onClose,
  });
  
  @override
  State<VoiceControlWidget> createState() => _VoiceControlWidgetState();
}

class _VoiceControlWidgetState extends State<VoiceControlWidget>
    with SingleTickerProviderStateMixin {
  final OnDeviceSpeechService _speechService = OnDeviceSpeechService();

  bool _isListening = false;
  String _statusText = 'Tap to speak';
  String _lastCommand = '';
  String _lastTranscription = '';
  bool _hasPermission = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeService();
    
    _pulseController = AnimationController(
      vsync: this,
      duration:  const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve:  Curves.easeInOut),
    );
    
    _pulseController.repeat(reverse: true);
  }
  
  Future<void> _initializeService() async {
    _speechService.onVoiceCommand = _handleVoiceCommand;
    _speechService.onTranscription = _handleTranscription;
    _speechService.onError = _handleError;
    // The native recognizer stops on its own after a pause; keep the UI in sync.
    _speechService.onListeningChanged = (listening) {
      if (!mounted) return;
      setState(() {
        _isListening = listening;
        if (!listening && _statusText == 'Listening...') {
          _statusText = 'Tap to speak';
        }
      });
    };

    _hasPermission = await _speechService.checkPermission();
    if (!_hasPermission && mounted) {
      setState(() {
        _statusText = 'Microphone permission required';
      });
    }
  }
  
  void _handleVoiceCommand(String command) {
    setState(() {
      _lastCommand = command;
      _statusText = 'Command: $command';
    });
    
    // Execute the command
    _executeCommand(command);
  }
  
  void _handleTranscription(String text) {
    setState(() {
      _lastTranscription = text;
    });
  }
  
  void _handleError(String error) {
    setState(() {
      _statusText = error;
    });
    
    // Reset after showing error
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusText = 'Tap to speak';
        });
      }
    });
  }
void _executeCommand(String command) {
  final destination = '/app/move/${widget.sessionCode}';
  
  // Handle typing command - send full text at once
  if (command.startsWith('type: ')) {
    final textToType = command.substring(6).trim();  // Add trim() to remove extra spaces
    
    print('[VoiceControl] Typing text: "$textToType"');
    
    widget.stompClient.send(
      destination: destination,
      body: jsonEncode({
        'action': 'type',
        'text': textToType,  // ✅ Send the entire text, not character by character
      }),
    );
    
    _showCommandFeedback('type:  $textToType');
    return;
  }
  
    
    // Handle other commands
    Map<String, dynamic>? actionData;
    
    switch (command) {
      case 'click':
        actionData = {'action': 'left_click'};
        break;
      case 'double_click': 
        actionData = {'action':  'double_click'};
        break;
      case 'right_click':
        actionData = {'action': 'right_click'};
        break;
      case 'scroll_up': 
        actionData = {'action':  'scroll', 'scroll_dy': 10.0};
        break;
      case 'scroll_down': 
        actionData = {'action': 'scroll', 'scroll_dy': -10.0};
        break;
      case 'backspace':
        actionData = {'action': 'backspace'};
        break;
      case 'enter':
        actionData = {'action': 'enter'};
        break;
      case 'escape':
        actionData = {'action': 'escape'};
        break;
      case 'copy':
        actionData = {'action': 'copy'};
        break;
      case 'paste':
        actionData = {'action': 'paste'};
        break;
      case 'undo':
        actionData = {'action': 'undo'};
        break;
      case 'select_all':
        actionData = {'action': 'select_all'};
        break;
    }
    
    if (actionData != null) {

       print('[VoiceControl] Sending action: $actionData');
      widget.stompClient.send(
        destination: destination,
        body: jsonEncode(actionData),
      );
      
      // Show feedback
      _showCommandFeedback(command);
    }
  }
  
  void _showCommandFeedback(String command) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Executed: $command'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green. shade700,
      ),
    );
  }
  
  Future<void> _toggleListening() async {
    if (! _hasPermission) {
      _hasPermission = await _speechService. checkPermission();
      if (!_hasPermission) {
        setState(() {
          _statusText = 'Please grant microphone permission';
        });
        return;
      }
    }
    
    if (_isListening) {
      // Stop listening; the final result (if any) is already handled live.
      setState(() {
        _isListening = false;
        _statusText = 'Tap to speak';
      });

      await _speechService.stopListening();
    } else {
      // Start a streaming listening session.
      setState(() {
        _isListening = true;
        _statusText = 'Listening...';
        _lastTranscription = '';
      });

      await _speechService.startListening();
    }
  }
  
@override
Widget build(BuildContext context) {
  return Container(
    padding:  const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius. circular(16),
    ),
    // ✅ Add constraint to prevent overflow
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,  // Max 80% of screen height
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header - Fixed at top
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:  [
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Colors.blueAccent,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Voice Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width:  8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius. circular(8),
                  ),
                  child: const Text(
                    'On-device',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize:  10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.onClose != null)
              IconButton(
                icon: const Icon(Icons. close, color: Colors.white54),
                onPressed: widget. onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        
      
        
        // ✅ Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Microphone button with fixed container
                SizedBox(
                  height: 100,
                  child: Center(
                    child: GestureDetector(
                      onTap:  _toggleListening,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening ? Colors.red :  Colors.blueAccent,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening ? Colors.red :  Colors.blueAccent)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height:  16),
                
                // Status text
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _isListening ? Colors.red.shade300 : Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Last transcription
                if (_lastTranscription.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius:  BorderRadius.circular(8),
                    ),
                    child:  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You said:',
                          style:  TextStyle(
                            color:  Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastTranscription,
                          style: const TextStyle(
                            color: Colors. white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                
                const SizedBox(height: 16),
                
                // Available commands hint
                Container(
                  padding:  const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:  Border.all(
                      color: Colors.blueAccent. withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Commands: ',
                        style: TextStyle(
                          color: Colors. blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing:  8,
                        runSpacing: 4,
                        children: [
                          _buildCommandChip('Click'),
                          _buildCommandChip('Double click'),
                          _buildCommandChip('Right click'),
                          _buildCommandChip('Scroll up/down'),
                          _buildCommandChip('Type [text]'),
                          _buildCommandChip('Enter'),
                          _buildCommandChip('Backspace'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildCommandChip(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical:  4),
    decoration: BoxDecoration(
      color: Colors.blueAccent.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
      ),
    ),
  );
}
  @override
  void dispose() {
    _pulseController.dispose();
    _speechService.dispose();
    super.dispose();
  }
}