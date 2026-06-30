import 'package:air_pointer/Services/connectionModeManager.dart';

import 'package:air_pointer/manualCodeEntryScreen.dart';
import 'package:air_pointer/qr_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ConnectionSelectionScreen extends StatefulWidget {
  const ConnectionSelectionScreen({super.key});

  @override
  State<ConnectionSelectionScreen> createState() => _ConnectionSelectionScreenState();
}

class _ConnectionSelectionScreenState extends State<ConnectionSelectionScreen> {
  final ConnectionModeManager _modeManager = ConnectionModeManager();
  final NetworkInfo _networkInfo = NetworkInfo();
  String?  _wifiIP;
  bool _isLoadingIP = false;

  @override
  void initState() {
    super.initState();
    _fetchWifiIP();
  }

  Future<void> _fetchWifiIP() async {
    setState(() {
      _isLoadingIP = true;
    });
    try {
      final wifiIP = await _networkInfo. getWifiIP();
      setState(() {
        _wifiIP = wifiIP;
        _isLoadingIP = false;
      });
    } catch (e) {
      setState(() {
        _wifiIP = null;
        _isLoadingIP = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          "Axilink",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment. bottomCenter,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ),
        child:  Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo/icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:  const Icon(
                    Icons.touch_app,
                    color: Colors.blueAccent,
                    size: 80,
                  ),
                ),
            
                const SizedBox(height:  30),
            
                // App title
                const Text(
                  "Connect to Axilink",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
            
                const SizedBox(height: 15),
            
                // Description
                const Text(
                  "Choose how you want to connect to the desktop application",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
            
                const SizedBox(height: 30),
            
                // Connection Mode Toggle (Cloud vs Local WiFi)
                _buildConnectionModeToggle(),
            
                const SizedBox(height: 30),
            
                // QR Code Option
                _buildConnectionOption(
                  context,
                  icon: Icons.qr_code_scanner,
                  title: "Scan QR Code",
                  description: _modeManager.isCloudMode
                      ? "Scan the QR code (4-digit code only)"
                      : "Scan the QR code with IP info",
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRCodeScannerScreen(),
                      ),
                    );
                  },
                ),
            
                const SizedBox(height: 20),
            
                // Manual Entry Option
                _buildConnectionOption(
                  context,
                  icon:  Icons.keyboard,
                  title: "Enter Code Manually",
                  description: _modeManager.isCloudMode
                      ? "Enter the 4-digit code (uses cloud server)"
                      : "Enter code & IP for local connection",
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator. push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManualCodeEntryScreen(),
                      ),
                    );
                  },
                ),
            
                // Show WiFi IP info for local mode
                if (_modeManager.isLocalWifiMode) ...[
                  const SizedBox(height: 20),
                  _buildWifiInfoCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionModeToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius:  BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Cloud Option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _modeManager.setMode(ConnectionMode.cloud);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _modeManager.isCloudMode
                      ? Colors.blueAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud,
                      color: _modeManager.isCloudMode
                          ? Colors. white
                          : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Cloud",
                      style: TextStyle(
                        color: _modeManager.isCloudMode
                            ? Colors.white
                            : Colors. white54,
                        fontSize:  16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Local WiFi Option
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _modeManager.setMode(ConnectionMode. localWifi);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets. symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _modeManager.isLocalWifiMode
                      ? Colors.greenAccent. shade700
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi,
                      color: _modeManager.isLocalWifiMode
                          ? Colors.white
                          : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Local WiFi",
                      style: TextStyle(
                        color: _modeManager.isLocalWifiMode
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi,
            color: Colors.greenAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Your WiFi IP",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoadingIP
                      ? "Detecting..."
                      : (_wifiIP ??  "Not connected to WiFi"),
                  style:  TextStyle(
                    color: _wifiIP != null ? Colors.white : Colors. redAccent,
                    fontSize:  16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchWifiIP,
            icon:  Icon(
              Icons.refresh,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:  color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color:  Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color. withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment. start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color:  Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style:  const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons. arrow_forward_ios,
                  color:  Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}