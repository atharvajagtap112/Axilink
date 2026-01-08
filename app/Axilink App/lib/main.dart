

import 'package:air_pointer/app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load( fileName: ".env");
  } catch (e) {
    debugPrint("ENV load failed: $e");
  }

  
  runApp(
   MyApp(),
  );
}

  