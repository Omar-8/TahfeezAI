import 'package:flutter/widgets.dart';

/// Arabic-script letters (Arabic, Urdu, Persian…), and Hebrew.
final _rtlLetter = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

/// A word meaning's own direction, from its script: right to left for
/// Urdu or Persian, left to right otherwise — whatever the app's language.
TextDirection meaningDirection(String text) =>
    _rtlLetter.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
