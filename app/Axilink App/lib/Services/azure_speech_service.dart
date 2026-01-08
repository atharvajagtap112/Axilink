import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:air_pointer/Services/azur_config.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';


/// Azure Speech Service for voice commands and speech-to-text
class AzureSpeechService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String?  _recordingPath;
  
  // Voice command callbacks
  Function(String command)? onVoiceCommand;
  Function(String text)? onTranscription;
  Function(String error)? onError;
  
  // Supported voice commands for Axilink
  static const Map<String, List<String>> voiceCommands = {
    'click': ['click', 'tap', 'select', 'press'],
    'double_click': ['double click', 'double tap', 'open'],
    'right_click': ['right click', 'right tap', 'context menu', 'menu'],
    'scroll_up': ['scroll up', 'go up', 'up'],
    'scroll_down': ['scroll down', 'go down', 'down'],
    'type': ['type', 'write', 'enter text'],
    'backspace': ['backspace', 'delete', 'remove'],
    'enter': ['enter', 'return', 'submit', 'send'],
    'escape': ['escape', 'cancel', 'close'],
    'copy': ['copy'],
    'paste': ['paste'],
    'undo': ['undo'],
    'select_all': ['select all'],
  };
  
  /// Check if microphone permission is available
  Future<bool> checkPermission() async {
    return await _audioRecorder.hasPermission();
  }
  
  /// Start recording audio for voice command
  Future<void> startRecording() async {
    try {
      if (_isRecording) return;
      
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        onError?.call('Microphone permission not granted');
        return;
      }
      
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/voice_command. wav';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath! ,
      );
      
      _isRecording = true;
      print('[AzureSpeech] Recording started');
    } catch (e) {
      onError?.call('Failed to start recording: $e');
      print('[AzureSpeech] Error starting recording: $e');
    }
  }
  
  /// Stop recording and process the voice command
  Future<String?> stopRecordingAndProcess() async {
    try {
      if (!_isRecording) return null;
      
      final path = await _audioRecorder.stop();
      _isRecording = false;
      print('[AzureSpeech] Recording stopped:  $path');
      
      if (path == null) {
        onError?. call('No recording path available');
        return null;
      }
      
      // Read the audio file
      final audioFile = File(path);
      if (!await audioFile.exists()) {
        onError?.call('Audio file not found');
        return null;
      }
      
      final audioBytes = await audioFile.readAsBytes();
      
      // Send to Azure Speech-to-Text
      final transcription = await _sendToAzureSpeechToText(audioBytes);
      
      if (transcription != null && transcription.isNotEmpty) {
        onTranscription?.call(transcription);
        
        // Parse voice command
        final command = _parseVoiceCommand(transcription);
        if (command != null) {
          onVoiceCommand?.call(command);
        }
        
        return transcription;
      }
      
      return null;
    } catch (e) {
      onError?.call('Failed to process recording: $e');
      print('[AzureSpeech] Error processing recording: $e');
      return null;
    }
  }
  
  /// Send audio to Azure Speech-to-Text API
  Future<String?> _sendToAzureSpeechToText(Uint8List audioBytes) async {
    try {
      final response = await http.post(
        Uri.parse(AzureConfig.speechToTextEndpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureConfig.speechKey,
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept': 'application/json',
        },
        body: audioBytes,
      );
      
      print('[AzureSpeech] Response status: ${response.statusCode}');
      print('[AzureSpeech] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response. body);
        final recognitionStatus = jsonResponse['RecognitionStatus'];
        
        if (recognitionStatus == 'Success') {
          return jsonResponse['DisplayText'];
        } else if (recognitionStatus == 'NoMatch') {
          onError?.call('Could not understand the audio');
        } else if (recognitionStatus == 'InitialSilenceTimeout') {
          onError?.call('No speech detected');
        }
      } else {
        onError?.call('Speech recognition failed: ${response.statusCode}');
      }
      
      return null;
    } catch (e) {
      onError?.call('Network error: $e');
      print('[AzureSpeech] Network error: $e');
      return null;
    }
  }


  String? _parseVoiceCommand(String transcription) {
  final lowerText = transcription.toLowerCase().trim();
  
  // Remove punctuation
  final cleanText = lowerText.replaceAll(RegExp(r'[^\w\s]'), '');
  
  print('[AzureSpeech] Parsing command from: "$cleanText"');
  
  // ⚠️ CRITICAL: Check multi-word commands FIRST (more specific before generic)
  // The order is VERY important here! 
  
  // Check for typing command FIRST (to avoid conflict with other commands)
  if (cleanText.startsWith('type ') || cleanText.startsWith('write ')) {
    final textToType = cleanText
        .replaceFirst(RegExp(r'^type '), '')
        .replaceFirst(RegExp(r'^write '), '');
    print('[AzureSpeech] Detected type command: $textToType');
    return 'type: $textToType';
  }
  
  // Check for "double click" BEFORE checking for "click"
  if (cleanText. contains('double click') || 
      cleanText.contains('double tap') || 
      cleanText.contains('doubleclick') ||
      cleanText.contains('double-click')) {
    print('[AzureSpeech] Detected command: double_click');
    return 'double_click';
  }
  
  // Check for "right click" BEFORE checking for "click"
  if (cleanText. contains('right click') || 
      cleanText.contains('right tap') || 
      cleanText. contains('rightclick') ||
      cleanText.contains('right-click') ||
      cleanText.contains('context menu')) {
    print('[AzureSpeech] Detected command: right_click');
    return 'right_click';
  }
  
  // Check for "select all" BEFORE checking for "select"
  if (cleanText. contains('select all') || cleanText.contains('selectall')) {
    print('[AzureSpeech] Detected command: select_all');
    return 'select_all';
  }
  
  // Check for scroll commands with multi-word phrases first
  if (cleanText.contains('scroll up') || cleanText.contains('go up')) {
    print('[AzureSpeech] Detected command:  scroll_up');
    return 'scroll_up';
  }
  
  if (cleanText.contains('scroll down') || cleanText.contains('go down')) {
    print('[AzureSpeech] Detected command: scroll_down');
    return 'scroll_down';
  }
  
  // NOW check for single-word "click" (after all multi-word click commands)
  if (cleanText.contains('click') || 
      cleanText.contains('tap') || 
      cleanText. contains('select') ||
      cleanText.contains('press')) {
    print('[AzureSpeech] Detected command:  click');
    return 'click';
  }
  
  // Check for single-word scroll commands
  if (cleanText.contains('up')) {
    print('[AzureSpeech] Detected command:  scroll_up');
    return 'scroll_up';
  }
  
  if (cleanText.contains('down')) {
    print('[AzureSpeech] Detected command: scroll_down');
    return 'scroll_down';
  }
  
  // Other single-word commands
  if (cleanText.contains('backspace') || cleanText.contains('delete')) {
    print('[AzureSpeech] Detected command:  backspace');
    return 'backspace';
  }
  
  if (cleanText.contains('enter') || 
      cleanText.contains('return') || 
      cleanText.contains('submit')) {
    print('[AzureSpeech] Detected command: enter');
    return 'enter';
  }
  
  if (cleanText.contains('escape') || cleanText.contains('cancel')) {
    print('[AzureSpeech] Detected command: escape');
    return 'escape';
  }
  
  if (cleanText.contains('copy')) {
    print('[AzureSpeech] Detected command:  copy');
    return 'copy';
  }
  
  if (cleanText.contains('paste')) {
    print('[AzureSpeech] Detected command: paste');
    return 'paste';
  }
  
  if (cleanText.contains('undo')) {
    print('[AzureSpeech] Detected command: undo');
    return 'undo';
  }
  
  print('[AzureSpeech] No command detected');
  return null;
}
  
  /// Text-to-Speech:  Convert text to speech (for feedback)
  Future<Uint8List? > textToSpeech(String text) async {
    try {
      final ssml = '''
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>
  <voice name='en-US-JennyNeural'>
    $text
  </voice>
</speak>''';
      
      final response = await http.post(
        Uri.parse(AzureConfig. textToSpeechEndpoint),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureConfig.speechKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-32kbitrate-mono-mp3',
        },
        body: ssml,
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      
      return null;
    } catch (e) {
      print('[AzureSpeech] TTS error: $e');
      return null;
    }
  }
  
  bool get isRecording => _isRecording;
  
  void dispose() {
    _audioRecorder.dispose();
  }
}