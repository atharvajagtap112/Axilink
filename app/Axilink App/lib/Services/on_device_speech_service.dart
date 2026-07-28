import 'package:speech_to_text/speech_to_text.dart' as stt;

/// On-device speech-to-text using the phone's native speech engine
/// (Android `SpeechRecognizer` / iOS `Speech`).
///
/// Drop-in replacement for the previous AzureSpeechService: it keeps the same
/// command-parsing surface (`onVoiceCommand`/`onTranscription`/`onError`) so the
/// existing VoiceControlWidget keeps working. Unlike Azure, this runs on-device,
/// needs no API key, costs nothing, and streams partial results in real time
/// (no record -> upload -> wait round-trip), so it feels noticeably faster.
class OnDeviceSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _available = false;
  bool _isListening = false;

  // Callbacks (match the old AzureSpeechService surface).
  Function(String command)? onVoiceCommand;
  Function(String text)? onTranscription;
  Function(String error)? onError;

  /// Fired whenever the engine starts/stops listening. The native recognizer
  /// stops itself after a pause in speech, so the UI needs this to stay in sync.
  Function(bool listening)? onListeningChanged;

  bool get isListening => _isListening;
  bool get isAvailable => _available;

  /// Initialize the native recognizer and verify availability + permission.
  /// Safe to call repeatedly; only the first call does real work.
  Future<bool> initialize() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onStatus: (status) {
        // Statuses: 'listening', 'notListening', 'done'.
        final listening = status == stt.SpeechToText.listeningStatus;
        if (_isListening != listening) {
          _isListening = listening;
          onListeningChanged?.call(listening);
        }
      },
      onError: (error) {
        _isListening = false;
        onListeningChanged?.call(false);
        onError?.call(_friendlyError(error.errorMsg));
      },
    );
    return _available;
  }

  /// Returns true when speech recognition is usable (mic permission granted and
  /// a recognizer is present). Mirrors the old AzureSpeechService.checkPermission.
  Future<bool> checkPermission() async {
    return await initialize();
  }

  /// Start a listening session. Results stream in via [onTranscription]; when the
  /// engine produces a final result we parse it and emit [onVoiceCommand].
  Future<void> startListening() async {
    if (!_available) {
      final ok = await initialize();
      if (!ok) {
        onError?.call('Speech recognition is not available on this device');
        return;
      }
    }
    if (_isListening) return;

    await _speech.listen(
      onResult: (result) {
        onTranscription?.call(result.recognizedWords);
        if (result.finalResult) {
          final command = _parseVoiceCommand(result.recognizedWords);
          if (command != null) {
            onVoiceCommand?.call(command);
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    _isListening = true;
    onListeningChanged?.call(true);
  }

  /// Stop listening but keep the last (partial) result.
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    _isListening = false;
    onListeningChanged?.call(false);
  }

  String _friendlyError(String raw) {
    switch (raw) {
      case 'error_no_match':
        return 'Could not understand the audio';
      case 'error_speech_timeout':
      case 'error_no_speech':
        return 'No speech detected';
      case 'error_permission':
        return 'Microphone permission not granted';
      default:
        return 'Speech recognition error: $raw';
    }
  }

  void dispose() {
    _speech.cancel();
  }

  /// Map a free-form transcription onto one of the Axilink remote-control
  /// commands. Identical rules to the previous Azure implementation: multi-word
  /// phrases are matched before the generic single words they contain.
  String? _parseVoiceCommand(String transcription) {
    final lowerText = transcription.toLowerCase().trim();

    // Remove punctuation.
    final cleanText = lowerText.replaceAll(RegExp(r'[^\w\s]'), '');

    print('[OnDeviceSpeech] Parsing command from: "$cleanText"');

    // Typing command FIRST (to avoid conflict with other commands).
    if (cleanText.startsWith('type ') || cleanText.startsWith('write ')) {
      final textToType = cleanText
          .replaceFirst(RegExp(r'^type '), '')
          .replaceFirst(RegExp(r'^write '), '');
      print('[OnDeviceSpeech] Detected type command: $textToType');
      return 'type: $textToType';
    }

    // "double click" BEFORE "click".
    if (cleanText.contains('double click') ||
        cleanText.contains('double tap') ||
        cleanText.contains('doubleclick') ||
        cleanText.contains('double-click')) {
      return 'double_click';
    }

    // "right click" BEFORE "click".
    if (cleanText.contains('right click') ||
        cleanText.contains('right tap') ||
        cleanText.contains('rightclick') ||
        cleanText.contains('right-click') ||
        cleanText.contains('context menu')) {
      return 'right_click';
    }

    // "select all" BEFORE "select".
    if (cleanText.contains('select all') || cleanText.contains('selectall')) {
      return 'select_all';
    }

    // Multi-word scroll phrases first.
    if (cleanText.contains('scroll up') || cleanText.contains('go up')) {
      return 'scroll_up';
    }
    if (cleanText.contains('scroll down') || cleanText.contains('go down')) {
      return 'scroll_down';
    }

    // Single-word "click" (after all multi-word click commands).
    if (cleanText.contains('click') ||
        cleanText.contains('tap') ||
        cleanText.contains('select') ||
        cleanText.contains('press')) {
      return 'click';
    }

    // Single-word scroll commands.
    if (cleanText.contains('up')) return 'scroll_up';
    if (cleanText.contains('down')) return 'scroll_down';

    // Other single-word commands.
    if (cleanText.contains('backspace') || cleanText.contains('delete')) {
      return 'backspace';
    }
    if (cleanText.contains('enter') ||
        cleanText.contains('return') ||
        cleanText.contains('submit')) {
      return 'enter';
    }
    if (cleanText.contains('escape') || cleanText.contains('cancel')) {
      return 'escape';
    }
    if (cleanText.contains('copy')) return 'copy';
    if (cleanText.contains('paste')) return 'paste';
    if (cleanText.contains('undo')) return 'undo';

    print('[OnDeviceSpeech] No command detected');
    return null;
  }
}
