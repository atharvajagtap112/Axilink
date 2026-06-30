import 'package:air_pointer/Services/connectionModeManager.dart';

import 'package:air_pointer/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final String cloudIP = dotenv.env['KEY'] ?? '';
  final ConnectionModeManager _modeManager = ConnectionModeManager();

  String? scannedCode;
  String?  extractedCode;
  String?  extractedIP;
  bool hasScanned = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          "Scan QR Code",
          style: TextStyle(
            color:  Colors.white,
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ),
        child: Column(
          children: [
            // Connection Mode Indicator
            _buildModeIndicator(),

            // Instructions
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius:  BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent. withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _modeManager.isCloudMode
                          ? "Scan the QR code with 4-digit code"
                          : "Scan the QR code with code + IP",
                      style: const TextStyle(
                        color: Colors. white,
                        fontSize: 16,
                        fontWeight:  FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // QR Scanner
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_modeManager.isCloudMode
                              ? Colors.blueAccent
                              : Colors.greenAccent)
                          .withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Mobile Scanner
                      MobileScanner(
                        controller: controller,
                        onDetect: _onDetect,
                      ),
                      // Custom Overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            // Overlay background with cutout
                            Container(
                              decoration: BoxDecoration(
                                color:  Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Container(
                                  width: 250,
                                  height: 250,
                                  decoration:  BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius:  BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _modeManager.isCloudMode
                                          ? Colors.blueAccent
                                          :  Colors.greenAccent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Corner indicators
                            Center(
                              child: SizedBox(
                                width:  250,
                                height: 250,
                                child: Stack(
                                  children: _buildCornerIndicators(),
                                ),
                              ),
                            ),
                            // Show processing indicator
                            if (isProcessing) _buildProcessingIndicator(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Scanned result display
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: hasScanned
                      ? Colors.greenAccent. withValues(alpha: 0.5)
                      : Colors.white. withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasScanned ? Icons.check_circle : Icons.qr_code,
                        color: hasScanned ? Colors.greenAccent : Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        hasScanned ? "Code Detected!" : "Waiting for scan...",
                        style: TextStyle(
                          color: 
                              hasScanned ? Colors.greenAccent : Colors.white70,
                          fontSize: 16,
                          fontWeight:  FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (hasScanned && extractedCode != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      extractedCode!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "URL: $extractedIP",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            if (hasScanned && extractedCode != null)
              Container(
                margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment:  MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 8),
                            Text("Scan Again"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _navigateToHomepage(extractedCode!, extractedIP!),
                        style:  ElevatedButton.styleFrom(
                          backgroundColor: _modeManager.isCloudMode
                              ? Colors.blueAccent
                              : Colors.greenAccent. shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment. center,
                          children: [
                            Icon(Icons.arrow_forward, size: 20),
                            SizedBox(width: 8),
                            Text("Continue"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
              ? Colors. blueAccent. withValues(alpha: 0.5)
              : Colors.greenAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _modeManager.isCloudMode ? Icons.cloud : Icons.wifi,
            color: _modeManager.isCloudMode
                ? Colors.blueAccent
                : Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _modeManager.isCloudMode ? "Cloud Mode" : "Local WiFi Mode",
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

  List<Widget> _buildCornerIndicators() {
    final color =
        _modeManager.isCloudMode ? Colors.blueAccent : Colors.greenAccent;
    return [
      // Top-left corner
      Positioned(
        top: -3,
        left: -3,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 6),
              left: BorderSide(color: color, width: 6),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
            ),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        top: -3,
        right: -3,
        child:  Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color:  color, width: 6),
              right: BorderSide(color: color, width: 6),
            ),
            borderRadius:  const BorderRadius.only(
              topRight: Radius.circular(20),
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        bottom: -3,
        left: -3,
        child: Container(
          width: 30,
          height: 30,
          decoration:  BoxDecoration(
            border:  Border(
              bottom: BorderSide(color: color, width:  6),
              left: BorderSide(color: color, width: 6),
            ),
            borderRadius: const BorderRadius. only(
              bottomLeft:  Radius.circular(20),
            ),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        bottom: -3,
        right: -3,
        child:  Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color:  color, width: 6),
              right: BorderSide(color: color, width: 6),
            ),
            borderRadius:  const BorderRadius.only(
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildProcessingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets. all(20),
        decoration:  BoxDecoration(
          color:  Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                _modeManager.isCloudMode
                    ? Colors.blueAccent
                    : Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Processing...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    // Prevent multiple simultaneous processing
    if (isProcessing || hasScanned) return;

    if (capture.barcodes.isNotEmpty) {
      final String?  code = capture.barcodes. first.rawValue;

      if (code != null) {
        setState(() {
          isProcessing = true;
        });

        // Add small delay to show processing state
        Future.delayed(const Duration(milliseconds: 500), () {
          // Parse the QR code data based on mode
          final parsedData = _parseQRCode(code);

          if (parsedData != null) {
            setState(() {
              scannedCode = code;
              extractedCode = parsedData['code'];
              extractedIP = parsedData['ip'];
              hasScanned = true;
              isProcessing = false;
            });

            // Stop camera after successful scan
            controller.stop();
          } else {
            setState(() {
              isProcessing = false;
            });

            // Show error for invalid code
            _showErrorDialog(_getErrorMessage());
          }
        });
      }
    }
  }

  String _getErrorMessage() {
    if (_modeManager.isCloudMode) {
      return "Invalid QR code format. Expected format: 4-digit code only (e.g., 1234)";
    } else {
      return "Invalid QR code format. Expected format: 4-digit code + IP address (e.g., 118810.194.204.188)";
    }
  }

  // Parse QR code data based on connection mode
  Map<String, String>? _parseQRCode(String qrData) {
    try {
      if (_modeManager.isCloudMode) {
        // Cloud mode:  QR code contains only 4-digit code
        // Regex for exactly 4 digits
        final cloudPattern = RegExp(r'^(\d{4})$');
        final match = cloudPattern.firstMatch(qrData);

        if (match != null) {
          final code = match.group(1)!;
          return {
            'code': code,
            'ip': cloudIP, // Use cloud URL from . env
          };
        }
      } else {
        // Local WiFi mode: QR code contains 4-digit code + IP address
        // Format: 118810.194.204.188 -> code: 1188, ip: 10.194.204.188
        // Regex:  First 4 digits as code, then IP address pattern
        final localPattern = RegExp(
          r'^(\d{4})(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$'
        );
        final match = localPattern.firstMatch(qrData);

        if (match != null) {
          final code = match.group(1)!; // First 4 digits
          final ipAddress = match.group(2)!; // IP address
          
          // Build the WebSocket URL from IP
          final wsUrl = 'ws://$ipAddress:8080/ws';
          
          return {
            'code': code,
            'ip': wsUrl,
          };
        }
      }

      return null;
    } catch (e) {
      print('Error parsing QR code: $e');
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF21262D),
        title: const Text(
          "Error",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed:  () {
              Navigator.of(dialogContext).pop();
              // Resume scanning after error
              if (! hasScanned) {
                controller. start();
              }
            },
            child: Text("OK",
                style: TextStyle(
                    color: _modeManager.isCloudMode
                        ? Colors.blueAccent
                        : Colors. greenAccent)),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      scannedCode = null;
      extractedCode = null;
      extractedIP = null;
      hasScanned = false;
      isProcessing = false;
    });
    controller.start();
  }

  void _navigateToHomepage(String code, String ip) {
    // Stop camera before navigation to prevent heating
    controller.stop();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Homepage(code: code, ip: ip),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    controller.stop();
    super.deactivate();
  }
}