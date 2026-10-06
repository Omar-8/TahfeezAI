import 'live_quran_recognizer.dart';

/// Non-web builds have no Web Speech API.
LiveQuranRecognizer? createWebSpeechRecognizer({String language = 'ar-SA'}) =>
    null;
