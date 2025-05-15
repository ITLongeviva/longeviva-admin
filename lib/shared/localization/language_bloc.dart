import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_model.dart';

/// Events
abstract class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object> get props => [];
}

class LanguageStarted extends LanguageEvent {
  const LanguageStarted();
}

class LanguageChanged extends LanguageEvent {
  final String languageCode;

  const LanguageChanged(this.languageCode);

  @override
  List<Object> get props => [languageCode];
}

/// States
class LanguageState extends Equatable {
  final Locale locale;
  final List<LanguageModel> supportedLanguages;

  const LanguageState({
    required this.locale,
    required this.supportedLanguages,
  });

  factory LanguageState.initial() {
    return const LanguageState(
      locale: Locale('it'),
      supportedLanguages: [
        LanguageModel(code: 'it', name: 'Italian'),
        LanguageModel(code: 'en', name: 'English'),
      ],
    );
  }

  LanguageState copyWith({
    Locale? locale,
    List<LanguageModel>? supportedLanguages,
  }) {
    return LanguageState(
      locale: locale ?? this.locale,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
    );
  }

  @override
  List<Object> get props => [locale, supportedLanguages];
}

/// BLoC
class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  static const String LANGUAGE_CODE_KEY = 'languageCode';

  LanguageBloc() : super(LanguageState.initial()) {
    on<LanguageStarted>(_onLanguageStarted);
    on<LanguageChanged>(_onLanguageChanged);
  }

  Future<void> _onLanguageStarted(
      LanguageStarted event,
      Emitter<LanguageState> emit,
      ) async {
    // Try to load saved language preference
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(LANGUAGE_CODE_KEY);

    if (savedLanguageCode != null) {
      emit(state.copyWith(locale: Locale(savedLanguageCode)));
    }
  }

  Future<void> _onLanguageChanged(
      LanguageChanged event,
      Emitter<LanguageState> emit,
      ) async {
    // Update the language preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_CODE_KEY, event.languageCode);

    // Update the state with the new locale
    emit(state.copyWith(locale: Locale(event.languageCode)));
  }
}