import 'package:flutter/material.dart';
import 'app_localizations.dart';

extension TranslationExtension on BuildContext {
  String tr(String key, {Map<String, String>? args}) {
    return AppLocalizations.of(this).translate(key, args: args);
  }
}