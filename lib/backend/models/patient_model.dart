import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String sex;
  final DateTime? birthdate;
  final DateTime? createdAt;
  final bool isActive;
  final String cityOfResidence;
  final String countryOfResidence;
  final List<String> conditions;
  final String? assignedDoctorId;
  final bool hasCompletedOnboarding;
  final DateTime? lastActivityAt;

  Patient({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    this.sex = '',
    this.birthdate,
    this.createdAt,
    this.isActive = true,
    this.cityOfResidence = '',
    this.countryOfResidence = '',
    this.conditions = const [],
    this.assignedDoctorId,
    this.hasCompletedOnboarding = false,
    this.lastActivityAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json, String docId) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is DateTime) return value;
      return null;
    }

    return Patient(
      id: docId,
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      email: json['email'] ?? '',
      sex: json['sex'] ?? '',
      birthdate: _parseDate(json['birthdate']),
      createdAt: _parseDate(json['createdAt']),
      isActive: json['isActive'] ?? true,
      cityOfResidence: json['cityOfResidence'] ?? '',
      countryOfResidence: json['countryOfResidence'] ?? '',
      conditions: json['conditions'] != null
          ? (json['conditions'] is List
              ? List<String>.from(json['conditions'])
              : [])
          : [],
      assignedDoctorId: json['assignedDoctorId'],
      hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
      lastActivityAt: _parseDate(json['lastActivityAt']),
    );
  }

  @override
  String toString() =>
      'Patient{id: $id, name: $name, surname: $surname, email: $email}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Patient && other.id == id && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
