import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, dynamic> _localizedStrings = {};

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static delegate that will load the appropriate language file
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Future<bool> load() async {
    // Load the language JSON file from the "lang" folder
    String jsonString = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap;
    return true;
  }

  // This method will be called from our widgets
  String translate(String key, {Map<String, String>? args}) {
    // Split the key by dots to navigate the nested JSON
    List<String> keys = key.split('.');
    dynamic value = _localizedStrings;

    // Traverse through the nested JSON
    for (String k in keys) {
      if (value == null || !(value is Map)) return key;
      value = value[k];
    }

    // If we couldn't find the translation, return the key itself
    if (value == null) return key;

    String translation = value.toString();

    // Replace placeholders if arguments are provided
    if (args != null) {
      args.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value);
      });
    }

    return translation;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all languages your app supports
    return ['it', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}