
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AzureConfig {

  static String speechKey =  dotenv.env['AZURE_SPEECH_KEY'] ?? '';
  static  String speechRegion = dotenv.env['AZURE_REGION'] ?? 'eastus';
  

  static  String visionKey = dotenv.env['AZURE_VISION_KEY'] ?? '';
  static const String visionEndpoint = 'https://axilink-cv.cognitiveservices.azure.com/';
  

  static String get speechToTextEndpoint => 
    'https://$speechRegion.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US';
  
  static String get textToSpeechEndpoint =>
    'https://$speechRegion.tts.speech.microsoft.com/cognitiveservices/v1';
  
  
  static String get ocrEndpoint => '${visionEndpoint}vision/v3.2/ocr';
  static String get analyzeEndpoint => '${visionEndpoint}vision/v3.2/analyze';
}
