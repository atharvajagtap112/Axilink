import 'package:air_pointer/homepage.dart';
import 'package:flutter/material.dart';

class ManualCodeEntryScreen extends StatefulWidget {
  const ManualCodeEntryScreen({super.key});

  @override
  State<ManualCodeEntryScreen> createState() => _ManualCodeEntryScreenState();
}

class _ManualCodeEntryScreenState extends State<ManualCodeEntryScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final String fixedIP = "ws://192.168.0.103:8080/ws";
  bool isCodeComplete = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to controllers
    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        _checkCodeCompletion();
      });
    }
  }

  void _checkCodeCompletion() {
    bool complete = true;
    for (final controller in _controllers) {
      if (controller.text.isEmpty) {
        complete = false;
        break;
      }
    }
    
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
    super.dispose();
  }

  void _navigateToHomepage() {
    final code = _controllers.map((controller) => controller.text).join();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Homepage(code: code, ip: fixedIP),
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
      // Wrap body in a SingleChildScrollView to handle keyboard appearance
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Instructions
                      Container(
                        margin: const EdgeInsets.only(top: 20, bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
                            SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                "Enter the 4-digit code displayed on your computer screen",
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

                      // Connection image
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Icon(
                          Icons.computer,
                          size: 100,
                          color: Colors.white24,
                        ),
                      ),

                      // Code input fields
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => _buildDigitInput(context, index),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Connection button
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 20, bottom: 20),
                        child: ElevatedButton(
                          onPressed: isCodeComplete ? _navigateToHomepage : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.link, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                isCodeComplete ? "Connect" : "Enter Complete Code",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // IP information
                     
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

  Widget _buildDigitInput(BuildContext context, int index) {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? Colors.blueAccent
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
        cursorColor: Colors.blueAccent,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
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