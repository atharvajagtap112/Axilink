import 'dart:async';


import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'dart:convert';

class MouseController extends StatefulWidget {
  const MouseController({super.key, this.stompClient, required this.code, required this.isActive, required this.onBack});
  
  final StompClient? stompClient;
  final String code;
  final bool isActive;
  final VoidCallback onBack;
  @override
  State<MouseController> createState() => _HomePagestate();
}

class _HomePagestate extends State<MouseController> {
 
  StompClient? stompClient;
   bool isPerformingAction = false;
   late final url;
  @override
  void initState() {
    super.initState();
      stompClient = widget.stompClient;
      url='/app/move/${widget.code}';
      
    
    _startGyroStream();
   
  }


  void _startGyroStream() {
    double alpha = 0.2; // smoothing factor

double smoothDx = 0;
double smoothDy = 0;
   double threshold = 0.02; // Lower threshold for more responsive movement
   double sensitivity = 8.0;
    Timer? sendTimer;
    double? lastDx;
    double? lastDy;

    gyroscopeEvents.listen((event) {
         
         if (isPerformingAction) return;
          
          if (widget.isActive == false) return;
       

      double dx = event.y * sensitivity;
      double dy = event.x * sensitivity;

     
    //  print("threshold: $threshold, sensitivity: $sensitivity");
      // Ignore very small movements (noise)
      if (dx.abs() < threshold) dx = 0;
      if (dy.abs() < threshold) dy = 0;

      // If no meaningful movement, don't send
      if (dx  == 0 && dy == 0) return;

      // Throttle sending data to max once every 80 ms
      if (sendTimer == null || !sendTimer!.isActive) {
        Map<String, dynamic> motionData = {'dx': dx, 'dy': dy};

        if (stompClient != null && stompClient!.connected) {
          stompClient!.send(
            destination:url,
            body: jsonEncode(motionData),
          );
          // print('url: $url'
          //   'Sent motion data: ${jsonEncode(motionData)}');
        }

        sendTimer = Timer(Duration(milliseconds: 50), () {});
      }
    });
  }

  void action(String action) {
    try {
      if (stompClient != null && stompClient!.connected) {
        stompClient!.send(
          destination: url,
          body: jsonEncode({'action': action}),
        );
        print('Sent action: $action');
      }
    } catch (e) {
      print('Error sending action: $e');
    }
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
Timer? actionCooldownTimer;
    Timer? scrollThrottleTimer;
double? latestScrollDy;
    return  PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          widget.onBack();
        }
      },
      child: Scaffold(
        
          backgroundColor: Color(0xFF0D1117),
          appBar: AppBar(
            title: Text(
              "Axilink",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Color(0xFF161B22),
            elevation: 0,
            centerTitle: true,
            leading: Icon(Icons.mouse, color: Colors.blueAccent),
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
                // Status indicator
                Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                  decoration: BoxDecoration(
                    color: Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Move your phone to control the cursor",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      
            
                  
      

      
      
                // Main control area with visual feedback
              GestureDetector(
        onPanUpdate: (details) {
       isPerformingAction = true;
      actionCooldownTimer?.cancel(); // Cancel any previous 
      actionCooldownTimer = Timer(Duration(milliseconds: 300), () {
        isPerformingAction = false;
      });
      
      double rawScrollDy = -details.delta.dy;
      double scrollDy = rawScrollDy.clamp(-3.0, 3.0);
      
      if (scrollDy.abs() > 0.1) {
        latestScrollDy = scrollDy;
      
        if (scrollThrottleTimer == null || !scrollThrottleTimer!.isActive) {
          // Send immediately and start timer
          if (stompClient != null && stompClient!.connected) {
            stompClient!.send(
              destination: url,
              body: jsonEncode({
                "action": "scroll",
                "scroll_dy": latestScrollDy,
              }),
            );
            print('Sent scroll: $latestScrollDy');
          }
      
          scrollThrottleTimer = Timer(Duration(milliseconds: 50), () {
            // After 50ms, if new scroll value exists, send it
            if (latestScrollDy != null) {
              if (stompClient != null && stompClient!.connected) {
                stompClient!.send(
                  destination: url,
                  body: jsonEncode({
                    "action": "scroll",
                    "scroll_dy": latestScrollDy,
                  }),
                );
                print('Sent throttled scroll: $latestScrollDy');
              }
            }
            scrollThrottleTimer = null;
            latestScrollDy = null;
          });
        }
      }
      
        
        },
        child: Container(
      height: 380,
      width: 500,
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Color(0xFF21262D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 60, color: Colors.blueAccent),
          SizedBox(height: 15),
          Center(child: Text("Use this area to scroll", style: TextStyle(color: Colors.white70))),
        ],
      ),
        ),
      ),
     
  Container(
          
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    // Left Click Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => action("left_click"),
                        onDoubleTap: () => action("double_click"),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4A9EFF), Color(0xFF0066CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF4A9EFF).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                             
                              SizedBox(height: 5),
                              Text(
                                "Left Click",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                             
                            ],
                          ),
                        ),
                      ),
                    ),
      
                    SizedBox(width: 15),
      
                    // Right Click Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => action("right_click"),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFCC0000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFF6B6B).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              
                              SizedBox(height: 5),
                              Text(
                                "Right Click",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                           
                            ],
                          ),
                        ),
                      ),
                    ),
      
                    SizedBox(width: 15),
      
                    // Scroll Button (Additional feature)
                   
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 30,
          )
      
                
              ],
            ),
          ),
         
        ),
    );
    
  }
}
