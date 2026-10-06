import 'live_quran_recognizer.dart';
import 'web_speech_live_recognizer.dart';

LiveQuranRecognizer? createWebSpeechRecognizer({String language = 'ar-SA'}) =>
    WebSpeechLiveRecognizer(language: language);
