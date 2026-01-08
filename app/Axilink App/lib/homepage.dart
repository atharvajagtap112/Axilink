import 'package:air_pointer/Screens/ScreenMirrorPage.dart';
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
  const Homepage({super.key, required this.code, required this.ip});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  StompClient? stompClient;
  bool isConnected = false;
  bool showModeSelection = true; // Start with mode selection
  String selectedMode = ''; // 'remote' or 'mirror'
  int _currentPage = 0; // For remote control mode tabs

  @override
  void initState() {
    super.initState();
    _connectStomp();
  }

  void _connectStomp() async {
    print('Connecting to WebSocket at ${widget.ip}');
    stompClient = StompClient(
      config: StompConfig(
        url: widget.ip!,
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

  void _selectMode(String mode) {
    setState(() {
      selectedMode = mode;
      showModeSelection = false;
    });
  }

  void _backToModeSelection() {
    setState(() {
      showModeSelection = true;
    });
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

    // Show mode selection screen
    if (showModeSelection) {
      return _buildModeSelectionScreen();
    }

    // Show selected mode
    if (selectedMode == 'mirror') {
      return ScreenMirrorPage(
        sessionCode: widget.code,
        stompClient: stompClient!,
        onBack: _backToModeSelection,
      );
    } else {
      return _buildRemoteControlScreen();
    }
  }

  Widget _buildModeSelectionScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Choose Mode - ${widget.code}'),
        backgroundColor: const Color(0xFF161B22),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            
            // Remote Control Option
            _buildModeCard(
              title: 'Remote Control',
              icon: Icons.mouse,
              description: 'Control mouse and keyboard remotely',
              color: Colors.blueAccent,
              onTap: () => _selectMode('remote'),
            ),
            
            const SizedBox(height: 20),
            
            // Screen Mirror Option
            _buildModeCard(
              title: 'Screen Mirroring',
              icon: Icons.screen_share,
              description: 'View and interact with desktop screen',
              color: Colors.greenAccent,
              onTap: () => _selectMode('mirror'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required IconData icon,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 40,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteControlScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
    
      body: Column(
        children: [
          

          // Keeping the original GestureDetector for swipe functionality
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: _handleSwipe,
              child: IndexedStack(
                index: _currentPage,
                children: [
                  MouseController(
                    stompClient: stompClient, 
                    code: widget.code,
                    isActive: _currentPage == 0 && selectedMode == 'remote',
                  ),
                  KeyboardScreen(
                    stompClient: stompClient!, 
                    code: widget.code,
                    isActive: _currentPage == 1 && selectedMode == 'remote',
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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