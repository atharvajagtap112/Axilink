import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';

class BasicKeyboard extends StatefulWidget {
  final StompClient stompClient;
  final String sessionCode;
  final VoidCallback onClose;

  const BasicKeyboard({
    Key? key,
    required this.stompClient,
    required this.sessionCode,
    required this.onClose,
  }) : super(key: key);

  @override
  State<BasicKeyboard> createState() => _BasicKeyboardState();
}

class _BasicKeyboardState extends State<BasicKeyboard> {
  // Position tracking for dragging
  Offset _offset = const Offset(20, 100);

  void _sendKey(String key) {
    try {
      if (widget.stompClient.connected) {
        if (key == "backspace") {
          widget.stompClient.send(
            destination: '/app/move/${widget.sessionCode}',
            body: jsonEncode({"action": "backspace"}),
          );
        } else if (key == "enter") {
          widget.stompClient.send(
            destination: '/app/move/${widget.sessionCode}',
            body: jsonEncode({"action": "type", "text": "\n"}),
          );
        } else if (key == "space") {
          widget.stompClient.send(
            destination: '/app/move/${widget.sessionCode}',
            body: jsonEncode({"action": "type", "text": " "}),
          );
        } else {
          widget.stompClient.send(
            destination: '/app/move/${widget.sessionCode}',
            body: jsonEncode({"action": "type", "text": key}),
          );
        }
        print('Sent key: $key');
      }
    } catch (e) {
      print('Error sending key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        // Make it draggable
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              _offset.dx + details.delta.dx,
              _offset.dy + details.delta.dy,
            );
          });
        },
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button only
            
              // Number row - direct implementation
              _buildSimpleRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']),
              
              // Letter rows - direct implementation
              _buildSimpleRow(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
              _buildSimpleRow(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l']),
              _buildSimpleRow(['z', 'x', 'c', 'v', 'b', 'n', 'm']),
              
              // Special keys row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                
                  _buildSpecialKey("Space", "space", 73),
                    _buildSpecialKey("⌫", "backspace", 38),
                  _buildSpecialKey("↵", "enter", 38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleRow(List<String> keys) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((key) {
        return InkWell(
          onTap: () => _sendKey(key),
          child: Container(
            width: 25, 
            height: 25,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.grey.shade800.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialKey(String label, String keyValue, double width) {
    return InkWell(
      onTap: () => _sendKey(keyValue),
      child: Container(
        width: width,
        height: 25,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: keyValue == "enter" 
              ? Colors.blueAccent.withOpacity(0.5)
              : Colors.grey.shade800.withOpacity(0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}



