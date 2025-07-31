import 'package:air_pointer/keyboard.dart';
import 'package:air_pointer/mouse_controller.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class Homepage extends StatefulWidget {
  final String code;
  final String? ip;
  const Homepage({super.key,required this.code, required this.ip});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  StompClient? stompClient;
  bool isConnected = false;
  int _currentPage = 0;

  KeyboardScreen? _keyboardScreen;
  MouseController? _mouseController;

  @override
  void initState() {
    super.initState();
    _connectStomp();
  }

  void _connectStomp() async{
       
      print('Connecting to WebSocket at ${widget.ip}');
    stompClient = StompClient(
      
      config: StompConfig(
        url:widget.ip!,
        onConnect: onConnectCallback,
        onDisconnect: onDisconnectCallback,
        onWebSocketError: (dynamic error) {
          print('WebSocket Error: $error');
          setState(() {
            isConnected = false;
          });
        },
        stompConnectHeaders: {},
        webSocketConnectHeaders: {},
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 30),
        heartbeatOutgoing: const Duration(seconds: 30),
      ),
    );

    stompClient!.activate();
  }

  void onConnectCallback(StompFrame frame) {
    setState(() {
      isConnected = true;
      // Don't create instances here - create them in build method with proper isActive values
    });
    print('✅ Connected to WebSocket');
  }

  void onDisconnectCallback(StompFrame frame) {
    setState(() {
      isConnected = false;
    });
    print('❌ Disconnected from WebSocket');

    Future.delayed(const Duration(seconds: 2), () {
      if (!isConnected && mounted) {
        _connectStomp();
      }
    });
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! < 0) {
      // Swipe Left
      if (_currentPage < 1) {
        setState(() {
          _currentPage++;
        });
      }
    } else if (details.primaryVelocity! > 0) {
      // Swipe Right
      if (_currentPage > 0) {
        setState(() {
          _currentPage--;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isConnected || stompClient == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
              SizedBox(height: 20),
              Text(
                'Connecting to server...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          const SizedBox(height: 20),
          
          // Navigation tabs
       

          const SizedBox(height: 10),

          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: _handleSwipe,
              child: IndexedStack(
                index: _currentPage,
                children: [
                  MouseController(
                    stompClient: stompClient, 
                    code: widget.code,
                    isActive: _currentPage == 0, // Mouse is active when on page 0
                  ),
                  KeyboardScreen(
                    stompClient: stompClient!, 
                    code: widget.code,
                    isActive: _currentPage == 1, // Keyboard is active when on page 1
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTab(int index, String title) {
    bool isSelected = _currentPage == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentPage = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white54,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}