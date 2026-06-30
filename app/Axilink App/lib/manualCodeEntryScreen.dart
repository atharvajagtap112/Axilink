
import 'package:air_pointer/Services/connectionModeManager.dart';
import 'package:air_pointer/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ManualCodeEntryScreen extends StatefulWidget {
  const ManualCodeEntryScreen({super.key});

  @override
  State<ManualCodeEntryScreen> createState() => _ManualCodeEntryScreenState();
}

class _ManualCodeEntryScreenState extends State<ManualCodeEntryScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List. generate(4, (_) => FocusNode());
  final TextEditingController _ipController = TextEditingController();
  final FocusNode _ipFocusNode = FocusNode();
  
  final String cloudIP = dotenv.env['KEY'] ?? '';
  final ConnectionModeManager _modeManager = ConnectionModeManager();
  final NetworkInfo _networkInfo = NetworkInfo();
  
  bool isCodeComplete = false;
  bool useAutoDetectedIP = true;
  String? _detectedWifiIP;
  bool _isLoadingIP = false;

  @override
  void initState() {
    super.initState();
    
    // Add listeners to controllers
    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        _checkCodeCompletion();
      });
    }
    
    _ipController.addListener(() {
      _checkCodeCompletion();
    });

    // Fetch WiFi IP if in local mode
    if (_modeManager.isLocalWifiMode) {
      _fetchWifiIP();
    }
  }

  Future<void> _fetchWifiIP() async {
    setState(() {
      _isLoadingIP = true;
    });
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      setState(() {
        _detectedWifiIP = wifiIP;
        _isLoadingIP = false;
      });
    } catch (e) {
      setState(() {
        _detectedWifiIP = null;
        _isLoadingIP = false;
      });
    }
  }

  void _checkCodeCompletion() {
    bool codeComplete = true;
    for (final controller in _controllers) {
      if (controller.text.isEmpty) {
        codeComplete = false;
        break;
      }
    }

    // For local WiFi mode, also check if IP is available
    bool ipComplete = true;
    if (_modeManager.isLocalWifiMode) {
      if (useAutoDetectedIP) {
        ipComplete = _detectedWifiIP != null && _detectedWifiIP!. isNotEmpty;
      } else {
        ipComplete = _ipController.text.isNotEmpty;
      }
    }

    bool complete = codeComplete && ipComplete;

    if (complete != isCodeComplete) {
      setState(() {
        isCodeComplete = complete;
      });
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    _ipController.dispose();
    _ipFocusNode. dispose();
    super.dispose();
  }

  String _buildWebSocketURL() {
    if (_modeManager.isCloudMode) {
      return cloudIP;
    } else {
      // Local WiFi mode
      String ip;
      if (useAutoDetectedIP) {
        ip = _detectedWifiIP ?? '';
      } else {
        ip = _ipController. text. trim();
      }
      // Build WebSocket URL:  ws://ip:8080/ws
      return 'ws://$ip:8080/ws';
    }
  }

  void _navigateToHomepage() {
    final code = _controllers. map((controller) => controller.text).join();
    final wsUrl = _buildWebSocketURL();
     print(wsUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Homepage(code: code, ip: wsUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          "Enter Code",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment. topCenter,
            end:  Alignment.bottomCenter,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child:  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Connection Mode Indicator
                      _buildModeIndicator(),

                      // Instructions
                      Container(
                        margin: const EdgeInsets.only(top: 15, bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:  const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blueAccent, size: 24),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                _modeManager.isCloudMode
                                    ? "Enter the 4-digit code displayed on your computer screen"
                                    : "Enter the 4-digit code and local IP address",
                                style:  const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight. w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Connection image
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Icon(
                          _modeManager.isCloudMode ?  Icons.cloud : Icons.wifi,
                          size: 80,
                          color: _modeManager.isCloudMode
                              ? Colors.blueAccent. withValues(alpha: 0.5)
                              : Colors.greenAccent.withValues(alpha: 0.5),
                        ),
                      ),

                      // Code input fields
                      Padding(
                        padding: const EdgeInsets. symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => _buildDigitInput(context, index),
                          ),
                        ),
                      ),

                      // Local WiFi IP Section (only show in local mode)
                      if (_modeManager.isLocalWifiMode) ...[
                        const SizedBox(height: 20),
                        _buildLocalIPSection(),
                      ],

                      const SizedBox(height: 30),

                      // Connection button
                      Container(
                        width: double. infinity,
                        margin: const EdgeInsets.only(top: 10, bottom: 20),
                        child: ElevatedButton(
                          onPressed: isCodeComplete ?  _navigateToHomepage : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _modeManager.isCloudMode
                                ? Colors.blueAccent
                                : Colors. greenAccent. shade700,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: 
                                Colors.blueAccent.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:  MainAxisAlignment.center,
                            children: [
                              Icon(
                                _modeManager.isCloudMode
                                    ? Icons.cloud
                                    : Icons.wifi,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isCodeComplete
                                    ? "Connect"
                                    : "Enter Complete Info",
                                style: const TextStyle(
                                  fontSize:  18,
                                  fontWeight:  FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Connection URL preview
                      if (isCodeComplete) _buildURLPreview(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _modeManager.isCloudMode
            ? Colors.blueAccent.withValues(alpha: 0.2)
            : Colors.greenAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _modeManager.isCloudMode
              ? Colors. blueAccent.withValues(alpha: 0.5)
              : Colors.greenAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _modeManager.isCloudMode ? Icons.cloud :  Icons.wifi,
            color:
                _modeManager.isCloudMode ? Colors.blueAccent : Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _modeManager.isCloudMode ?  "Cloud Mode" : "Local WiFi Mode",
            style: TextStyle(
              color: _modeManager.isCloudMode
                  ? Colors.blueAccent
                  : Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalIPSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius:  BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Local IP Address",
            style: TextStyle(
              color: Colors. white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          // Auto-detect toggle
          Row(
            children:  [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      useAutoDetectedIP = true;
                      _checkCodeCompletion();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: useAutoDetectedIP
                          ?  Colors.greenAccent.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border. all(
                        color: useAutoDetectedIP
                            ?  Colors.greenAccent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_fix_high,
                          color:  useAutoDetectedIP
                              ? Colors.greenAccent
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Auto Detect",
                          style: TextStyle(
                            color: useAutoDetectedIP
                                ?  Colors.greenAccent
                                : Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      useAutoDetectedIP = false;
                      _checkCodeCompletion();
                    });
                  },
                  child: Container(
                    padding:  const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: ! useAutoDetectedIP
                          ? Colors.orangeAccent.withValues(alpha: 0.2)
                          :  Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border. all(
                        color: ! useAutoDetectedIP
                            ? Colors.orangeAccent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit,
                          color: !useAutoDetectedIP
                              ?  Colors.orangeAccent
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Manual Entry",
                          style: TextStyle(
                            color: !useAutoDetectedIP
                                ? Colors.orangeAccent
                                : Colors.white54,
                            fontSize: 14,
                            fontWeight:  FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Auto-detected IP display
          if (useAutoDetectedIP) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius:  BorderRadius.circular(10),
                border: Border.all(
                  color: _detectedWifiIP != null
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : Colors.redAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _detectedWifiIP != null ?  Icons.check_circle : Icons.error,
                    color: _detectedWifiIP != null
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:  CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoadingIP
                              ? "Detecting IP..."
                              : (_detectedWifiIP ??  "WiFi not connected"),
                          style: TextStyle(
                            color: _detectedWifiIP != null
                                ? Colors.white
                                : Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_detectedWifiIP != null)
                          Text(
                            "Auto-detected from WiFi",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchWifiIP,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Manual IP input
            TextField(
              controller: _ipController,
              focusNode: _ipFocusNode,
              keyboardType:  TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: "Enter IP (e.g., 192.168.1.5)",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.computer, color: Colors.orangeAccent),
                filled:  true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius:  BorderRadius.circular(10),
                  borderSide:  BorderSide(color: Colors.orangeAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:  BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.orangeAccent, width: 2),
                ),
              ),
              onChanged:  (_) => _checkCodeCompletion(),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter the IP address of your computer running Axilink",
              style:  TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildURLPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius:  BorderRadius.circular(10),
        border: Border.all(color: Colors.white. withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Connection URL Preview",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _buildWebSocketURL(),
            style: TextStyle(
              color:  Colors.white70,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitInput(BuildContext context, int index) {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius:  BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border:  Border.all(
          color: _controllers[index].text.isNotEmpty
              ? (_modeManager.isCloudMode
                  ? Colors.blueAccent
                  : Colors.greenAccent)
              : Colors.white24,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        cursorColor: _modeManager.isCloudMode
            ? Colors.blueAccent
            : Colors.greenAccent,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets. zero,
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 3) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
            }
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}