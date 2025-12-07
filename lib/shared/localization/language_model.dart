import 'package:equatable/equatable.dart';

class LanguageModel extends Equatable {
  final String code;
  final String name;

  const LanguageModel({
    required this.code,
    required this.name,
  });

  @override
  List<Object> get props => [code, name];
}