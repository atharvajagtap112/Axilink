import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:air_pointer/utils/enhancedKeyboardPanel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_handler.dart';

class ScreenMirrorPage extends StatefulWidget {
  final String sessionCode;
  final StompClient stompClient;
  final VoidCallback onBack;

  const ScreenMirrorPage({
    Key? key,
    required this.sessionCode,
    required this.stompClient,
    required this.onBack,
  }) : super(key: key);

  @override
  State<ScreenMirrorPage> createState() => _ScreenMirrorPageState();
}

class _ScreenMirrorPageState extends State<ScreenMirrorPage> {
  Uint8List? _imageBytes;
  bool _isConnected = false;
  bool _isLoading = true;
  String _statusMessage = 'Waiting for screen connection...';
  bool _hasError = false;
  double _aspectRatio = 16 / 9;

  // For subscription management
  Function? _screenSubscription;
  int _frameCount = 0;
  Timer? _frameCounterTimer;
  Timer? _reconnectTimer;

  // For chunked image reassembly
  final Map<String, Map<int, String>> _imageChunks = {};
  final Map<String, int> _totalChunks = {};

  // Keyboard control
  bool _showKeyboard = false;
  
  // For scroll handling
  bool _isScrolling = false;
  Timer? _scrollThrottleTimer;
  double? _latestScrollDy;
  
  // For touch gesture disambiguation
  Offset? _touchStartPosition;
  DateTime? _touchStartTime;
  bool _isPotentialScroll = false;
  static const double _scrollThreshold = 10.0; // pixels to move before considering it a scroll
  static const Duration _tapTimeout = Duration(milliseconds: 300); // max time for a tap
  
  // Add a new variable to store the position of the last tap for double-tap handling
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    _requestMirrorMode();
    _subscribeToScreenFrames();

    _reconnectTimer = Timer(const Duration(seconds: 8), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _statusMessage = 'No screen data received. Please check desktop application.';
        });
        _reconnect();
      }
    });

    _frameCounterTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        print('Frame count in last 5s: $_frameCount');
        if (_frameCount == 0 && !_isLoading) {
          setState(() {
            _hasError = true;
            _statusMessage = 'Screen mirroring stopped. Reconnecting...';
          });
          _reconnect();
        }
        _frameCount = 0;
        _cleanupOldChunks();
      }
    });
  }

  void _cleanupOldChunks() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToRemove = <String>[];

    for (final entry in _imageChunks.entries) {
      final frameId = entry.key;
      try {
        final timestamp = int.parse(frameId);
        if (now - timestamp > 5000) {
          keysToRemove.add(frameId);
        }
      } catch (_) {
        keysToRemove.add(frameId);
      }
    }

    for (final key in keysToRemove) {
      _imageChunks.remove(key);
      _totalChunks.remove(key);
    }
  }

  void _reconnect() {
    _requestMirrorMode();
    Future.delayed(const Duration(seconds: 3), () {
      if (_hasError && mounted && _frameCount == 0) {
        setState(() {
          _statusMessage = 'Unable to reconnect. Desktop client may have disconnected.';
        });
      }
    });
  }

  void _requestMirrorMode() {
    print('Requesting mirror mode for session ${widget.sessionCode}');
    try {
      widget.stompClient.send(
        destination: '/app/mode/${widget.sessionCode}',
        body: jsonEncode({
          'mode': 'mirror',
        }),
      );
    } catch (e) {
      print('Error requesting mirror mode: $e');
      setState(() {
        _hasError = true;
        _statusMessage = 'Error requesting mirror mode: $e';
      });
    }
  }

  void _subscribeToScreenFrames() {
    try {
      print('Subscribing to screen frames');

      _screenSubscription = widget.stompClient.subscribe(
        destination: '/topic/screen/${widget.sessionCode}',
        callback: (frame) {
          if (frame.body == null) return;

          try {
            final data = jsonDecode(frame.body!);
            if (data.containsKey('imageChunk')) {
              _handleImageChunk(data);
              return;
            }

            if (data.containsKey('image')) {
              final imageBase64 = data['image'] as String;
              final aspectRatio = data.containsKey('aspectRatio')
                  ? (data['aspectRatio'] as num).toDouble()
                  : _aspectRatio;
              setState(() {
                _imageBytes = base64Decode(imageBase64);
                _isConnected = true;
                _isLoading = false;
                _hasError = false;
                _aspectRatio = aspectRatio;
                _frameCount++;
              });
            }
          } catch (e) {
            print('Error processing frame: $e');
            setState(() {
              _hasError = true;
              _isLoading = false;
              _statusMessage = 'Error processing screen data';
            });
          }
        },
      );

      print('Subscribed to screen frames');
    } catch (e) {
      print('Error subscribing to screen frames: $e');
      setState(() {
        _hasError = true;
        _statusMessage = 'Error subscribing to screen frames: $e';
      });
    }
  }

  void _handleImageChunk(Map<String, dynamic> data) {
    try {
      final String chunk = data['imageChunk'];
      final int chunkIndex = data['chunkIndex'];
      final int totalChunks = data['totalChunks'];
      final String frameId = data['frameId'];
      final double aspectRatio = data.containsKey('aspectRatio')
          ? (data['aspectRatio'] as num).toDouble()
          : _aspectRatio;

      if (!_imageChunks.containsKey(frameId)) {
        _imageChunks[frameId] = {};
        _totalChunks[frameId] = totalChunks;
      }

      _imageChunks[frameId]![chunkIndex] = chunk;

      if (_imageChunks[frameId]!.length == totalChunks) {
        final StringBuffer fullImage = StringBuffer();
        for (int i = 0; i < totalChunks; i++) {
          fullImage.write(_imageChunks[frameId]![i]);
        }
        setState(() {
          _imageBytes = base64Decode(fullImage.toString());
          _isConnected = true;
          _isLoading = false;
          _hasError = false;
          _aspectRatio = aspectRatio;
          _frameCount++;
        });
        _imageChunks.remove(frameId);
        _totalChunks.remove(frameId);
      }
    } catch (e) {
      print('Error handling chunked image: $e');
    }
  }

  void _sendTouchEvent(Offset localPosition, Size size, String clickType) {
    try {
      final xPercent = localPosition.dx / size.width;
      final yPercent = localPosition.dy / size.height;
      print('Sending touch event: $clickType at ($xPercent, $yPercent)');
      print('Touch position: ${localPosition.dx}x${localPosition.dy} on screen ${size.width}x${size.height}');
      widget.stompClient.send(
        destination: '/app/touch/${widget.sessionCode}',
        body: jsonEncode({
          'xPercent': xPercent,
          'yPercent': yPercent,
          'clickType': clickType,
          'isLandscape': true,
        }),
      );
    } catch (e) {
      print('Error sending touch event: $e');
    }
  }
  
  void _sendScrollEvent(double scrollDy) {
    try {
      // Reverse the scroll direction (when you scroll down, screen should scroll up)
      double reversedScrollDy = -scrollDy;
      
      print('Sending scroll event: $reversedScrollDy');
      widget.stompClient.send(
        destination: '/app/move/${widget.sessionCode}',
        body: jsonEncode({
          'action': 'scroll',
          'scroll_dy': reversedScrollDy,
        }),
      );
    } catch (e) {
      print('Error sending scroll event: $e');
    }
  }

  void _toggleKeyboard() {
    setState(() {
      _showKeyboard = !_showKeyboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _isConnected && _imageBytes != null && !_hasError
                ? _buildScreenView()
                : _buildErrorView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenView() {
    return Stack(
      children: [
        // Main screen image
        Center(
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Image.memory(
              _imageBytes!,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        // Touch and scroll event handler - Using a different approach
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            // Use Listener for low-level pointer events instead of GestureDetector
            onPointerDown: (event) {
              if (_showKeyboard) return;
              
              _touchStartPosition = event.localPosition;
              _touchStartTime = DateTime.now();
              _isPotentialScroll = false;
              _isScrolling = false;
              
              // Store the position for double tap
              _lastTapPosition = event.localPosition;
              
              // We don't send click events immediately anymore - we wait to see if it's a scroll
            },
            
            onPointerMove: (event) {
              if (_showKeyboard) return;
              
              if (_touchStartPosition != null) {
                final dx = event.localPosition.dx - _touchStartPosition!.dx;
                final dy = event.localPosition.dy - _touchStartPosition!.dy;
                final distance = sqrt(dx * dx + dy * dy);
                
                // If we move more than the threshold, it's a potential scroll
                if (distance > _scrollThreshold) {
                  _isPotentialScroll = true;
                  
                  // If we're primarily moving vertically, it's a scroll
                  if (dy.abs() > dx.abs() * 1.2) {
                    if (!_isScrolling) {
                      setState(() {
                        _isScrolling = true;
                      });
                    }
                    
                    double scrollDy = event.delta.dy;
                    double clampedScrollDy = scrollDy.clamp(-3.0, 3.0);
                    
                    if (clampedScrollDy.abs() > 0.1) {
                      _latestScrollDy = clampedScrollDy;
                      
                      if (_scrollThrottleTimer == null || !_scrollThrottleTimer!.isActive) {
                        _sendScrollEvent(_latestScrollDy!);
                        
                        _scrollThrottleTimer = Timer(const Duration(milliseconds: 50), () {
                          if (_latestScrollDy != null) {
                            _sendScrollEvent(_latestScrollDy!);
                          }
                          _scrollThrottleTimer = null;
                          _latestScrollDy = null;
                        });
                      }
                    }
                  }
                }
              }
            },
            
            onPointerUp: (event) {
              if (_showKeyboard) return;
              
              final endTime = DateTime.now();
              
              // Only send tap events if:
              // 1. We haven't moved much (not a scroll)
              // 2. The touch was short enough (quick tap)
              // 3. We're not in the middle of scrolling
              if (_touchStartPosition != null && 
                  !_isPotentialScroll && 
                  !_isScrolling && 
                  endTime.difference(_touchStartTime!) < _tapTimeout) {
                
                final renderBox = context.findRenderObject() as RenderBox;
                _sendTouchEvent(event.localPosition, renderBox.size, 'left_click');
              }
              
              // Reset state
              _touchStartPosition = null;
              _touchStartTime = null;
              
              // Give a short delay before allowing clicks again
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _isScrolling = false;
                    _isPotentialScroll = false;
                  });
                }
              });
            },
            
            onPointerCancel: (event) {
              _touchStartPosition = null;
              _touchStartTime = null;
              _isPotentialScroll = false;
              
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _isScrolling = false;
                  });
                }
              });
            },
            
            // Child needs to be transparent
            child: GestureDetector(
              // Handle double taps and long presses with GestureDetector
              // These won't interfere with our Listener for scrolling/tapping
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                if (_showKeyboard || _isScrolling) return;
                
                final renderBox = context.findRenderObject() as RenderBox;
                
                // Use the current tap position for double tap instead of the start position
                // This is the key fix! Use _lastTapPosition instead of _touchStartPosition
                final tapPosition = _lastTapPosition ?? Offset(renderBox.size.width / 2, renderBox.size.height / 2);
                _sendTouchEvent(tapPosition, renderBox.size, 'double_click');
              },
              onLongPress: () {
                if (_showKeyboard || _isScrolling || _isPotentialScroll) return;
                
                final renderBox = context.findRenderObject() as RenderBox;
                // Also use _lastTapPosition here for consistency
                final tapPosition = _lastTapPosition ?? Offset(renderBox.size.width / 2, renderBox.size.height / 2);
                _sendTouchEvent(tapPosition, renderBox.size, 'right_click');
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        
       
        // Keyboard toggle button
        Positioned(
          right: 18,
          top: 20,
          child: GestureDetector(
            onTap: _toggleKeyboard,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.keyboard, color: Colors.white, size: 24),
            ),
          ),
        ),
        
        // Keyboard when shown
        if (_showKeyboard)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BasicKeyboard(
              stompClient: widget.stompClient,
              sessionCode: widget.sessionCode,
              onClose: _toggleKeyboard,
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _statusMessage = 'Reconnecting...';
              });
              _requestMirrorMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _switchToControlMode() {
    try {
      print('Switching to control mode');
      widget.stompClient.send(
        destination: '/app/mode/${widget.sessionCode}',
        body: jsonEncode({
          'mode': 'control',
        }),
      );
    } catch (e) {
      print('Error switching to control mode: $e');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (_screenSubscription != null) {
      try {
        _screenSubscription!();
        print('Unsubscribed from screen frames');
      } catch (e) {
        print('Error unsubscribing from screen frames: $e');
      }
    }
    _frameCounterTimer?.cancel();
    _reconnectTimer?.cancel();
    _scrollThrottleTimer?.cancel();
    _switchToControlMode();
    super.dispose();
  }
}