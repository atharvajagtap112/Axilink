import 'dart:async';


import 'package:flutter/material.dart';
import 'package:get/state_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'dart:convert';

class MouseController extends StatefulWidget {
  const MouseController({super.key, this.stompClient, required this.code,required this.isActive});
  
  final StompClient? stompClient;
  final String code;
  final bool isActive;
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
      
    // if(stompClient == null) {
    //   _connectStomp();
    // }
   
    _startGyroStream();
   
  }

  // void _connectStomp() {
  //   stompClient = StompClient(
  //     config: StompConfig(
  //       url: 'ws://192.168.0.101:8080/ws',
  //       onConnect: onConnectCallback,
  //       onWebSocketError: (dynamic error) => print('WebSocket Error: $error'),
  //       stompConnectHeaders: {},
  //       webSocketConnectHeaders: {},
  //     ),
  //   );

  //   stompClient!.activate();
  // }

  // void onConnectCallback(StompFrame frame) {
  //   print('Connected to WebSocket!');
  // }

  // For Timer

  void _startGyroStream() {
   double threshold = 0.05; // Lower threshold for more responsive movement
   double sensitivity = 8.0;
    Timer? sendTimer;
    double? lastDx;
    double? lastDy;

    gyroscopeEvents.listen((event) {
         
         if (isPerformingAction) return;
          
          if (widget.isActive == false) return;
       

      double dx = event.y * sensitivity;
      double dy = event.x * sensitivity;

      double acceleration = (dx.abs() > 1.0 || dy.abs() > 1.0) ? 1.5 : 1.0;
dx *= acceleration;
dy *= acceleration;
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

        sendTimer = Timer(Duration(milliseconds: 80), () {});
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
Timer? _actionCooldownTimer;
    Timer? _scrollThrottleTimer;
double? _latestScrollDy;
    return  Scaffold(
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
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.1),
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
                            color: Colors.greenAccent.withOpacity(0.5),
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

              Spacer(),
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
                              color: Color(0xFF4A9EFF).withOpacity(0.3),
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
                              color: Color(0xFFFF6B6B).withOpacity(0.3),
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

 Spacer(),


              // Main control area with visual feedback
            GestureDetector(
  onPanUpdate: (details) {
     isPerformingAction = true;
_actionCooldownTimer?.cancel(); // Cancel any previous 
_actionCooldownTimer = Timer(Duration(milliseconds: 300), () {
  isPerformingAction = false;
});

    double rawScrollDy = -details.delta.dy;
    double scrollDy = rawScrollDy.clamp(-3.0, 3.0);

    if (scrollDy.abs() > 0.1) {
      _latestScrollDy = scrollDy;

      if (_scrollThrottleTimer == null || !_scrollThrottleTimer!.isActive) {
        // Send immediately and start timer
        if (stompClient != null && stompClient!.connected) {
          stompClient!.send(
            destination: url,
            body: jsonEncode({
              "action": "scroll",
              "scroll_dy": _latestScrollDy,
            }),
          );
          print('Sent scroll: $_latestScrollDy');
        }

        _scrollThrottleTimer = Timer(Duration(milliseconds: 50), () {
          // After 50ms, if new scroll value exists, send it
          if (_latestScrollDy != null) {
            if (stompClient != null && stompClient!.connected) {
              stompClient!.send(
                destination: url,
                body: jsonEncode({
                  "action": "scroll",
                  "scroll_dy": _latestScrollDy,
                }),
              );
              print('Sent throttled scroll: $_latestScrollDy');
            }
          }
          _scrollThrottleTimer = null;
          _latestScrollDy = null;
        });
      }
    }

  
  },
  child: Container(
    height: 430,
    width: 500,
    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    padding: EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Color(0xFF21262D),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
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

              
            ],
          ),
        ),
       
      );
    
  }
}
