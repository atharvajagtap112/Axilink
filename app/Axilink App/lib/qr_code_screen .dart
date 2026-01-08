import 'package:air_pointer/homepage.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  MobileScannerController controller = MobileScannerController(
    // Add configuration to reduce heating
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  String? scannedCode;
  String? extractedCode;
  String? extractedIP;
  bool hasScanned = false;
  bool isProcessing = false; // Add this to prevent multiple scans

  @override
  void initState() {
    super.initState();
    // Start camera when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          "Scan QR Code",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF161B22),
        elevation: 0,
        centerTitle: true,
        leading: Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ),
        child: Column(
          children: [
            // Instructions
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF21262D),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Scan the QR code to get the 4-digit connection code",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 5),
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
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Container(
                                  width: 250,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Corner indicators
                            Center(
                              child: Container(
                                width: 250,
                                height: 250,
                                child: Stack(
                                  children: [
                                    // Top-left corner
                                    Positioned(
                                      top: -3,
                                      left: -3,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Colors.blueAccent, width: 6),
                                            left: BorderSide(color: Colors.blueAccent, width: 6),
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Top-right corner
                                    Positioned(
                                      top: -3,
                                      right: -3,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Colors.blueAccent, width: 6),
                                            right: BorderSide(color: Colors.blueAccent, width: 6),
                                          ),
                                          borderRadius: BorderRadius.only(
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
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.blueAccent, width: 6),
                                            left: BorderSide(color: Colors.blueAccent, width: 6),
                                          ),
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Bottom-right corner
                                    Positioned(
                                      bottom: -3,
                                      right: -3,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.blueAccent, width: 6),
                                            right: BorderSide(color: Colors.blueAccent, width: 6),
                                          ),
                                          borderRadius: BorderRadius.only(
                                            bottomRight: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Show processing indicator
                            if (isProcessing)
                              Center(
                                child: Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        "Processing...",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
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
              ),
            ),

            // Scanned result display
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF21262D),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: hasScanned 
                    ? Colors.greenAccent.withOpacity(0.5) 
                    : Colors.white.withOpacity(0.1)
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasScanned ? Icons.check_circle : Icons.qr_code,
                        color: hasScanned ? Colors.greenAccent : Colors.white70,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        hasScanned ? "Code Detected!" : "Waiting for scan...",
                        style: TextStyle(
                          color: hasScanned ? Colors.greenAccent : Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (hasScanned && extractedCode != null) ...[
                    SizedBox(height: 15),
                    Text(
                      extractedCode!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "URL: $extractedIP",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            if (hasScanned && extractedCode != null)
              Container(
                margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF21262D),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 8),
                            Text("Scan Again"),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToHomepage(extractedCode!, extractedIP!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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

  void _onDetect(BarcodeCapture capture) {
    // Prevent multiple simultaneous processing
    if (isProcessing || hasScanned) return;

    if (capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      
      if (code != null) {
        setState(() {
          isProcessing = true;
        });

        // Add small delay to show processing state
        Future.delayed(Duration(milliseconds: 500), () {
          // Parse the QR code data
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
            _showErrorDialog("Invalid QR code format. Expected format: 4-digit code + ws://ip:8080/ws");
          }
        });
      }
    }
  }

  // Parse QR code data in format: code + "ws://{ip}:8080/ws"
  Map<String, String>? _parseQRCode(String qrData) {
    try {
      // Check if the string contains the websocket URL pattern
      final wsPattern = RegExp(r'^(\d{4})(ws://[^:]+:8080/ws)$');
      final match = wsPattern.firstMatch(qrData);
      
      if (match != null) {
        final code = match.group(1)!; // First 4 digits
        final wsUrl = match.group(2)!; // Full WebSocket URL
        
        return {
          'code': code,
          'ip': wsUrl, // Now contains full WebSocket URL
        };
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
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Color(0xFF21262D),
        title: Text(
          "Error",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Use dialogContext
              // Resume scanning after error
              if (!hasScanned) {
                controller.start();
              }
            },
            child: Text("OK", style: TextStyle(color: Colors.blueAccent)),
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
    // Ensure camera is stopped when disposing
    controller.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Stop camera when screen is not active
    controller.stop();
    super.deactivate();
  }
}

// Custom painter for scanning line animation
class ScannerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw animated scanning line
    final center = size.height / 2;
    final line = Path()
      ..moveTo(20, center)
      ..lineTo(size.width - 20, center);

    canvas.drawPath(line, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}