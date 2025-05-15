import 'package:cloud_firestore/cloud_firestore.dart';

class SignupRequest {
  final String id;
  final String role; // DOCTOR or CLINIC
  final String name;
  final String surname;
  final String sex;
  final DateTime? birthdate;
  final String specialty;
  final String phoneNumber;
  final String cityOfWork;
  final String email;
  final String googleEmail;
  final String vatNumber;
  final String fiscalCode;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? deleteAt;
  final String? temporaryPassword;
  final String? rejectionReason;

  SignupRequest({
    required this.id,
    required this.role,
    required this.name,
    required this.surname,
    required this.sex,
    this.birthdate,
    required this.specialty,
    required this.phoneNumber,
    required this.cityOfWork,
    required this.email,
    required this.googleEmail,
    required this.vatNumber,
    required this.fiscalCode,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.deleteAt,
    this.temporaryPassword,
    this.rejectionReason,
  });

  factory SignupRequest.fromJson(Map<String, dynamic> json, String docId) {
    return SignupRequest(
      id: docId,
      role: json['role'] ?? 'DOCTOR',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      sex: json['sex'] ?? '',
      birthdate: json['birthdate'] != null ?
      (json['birthdate'] is Timestamp ?
      (json['birthdate'] as Timestamp).toDate() :
      DateTime.parse(json['birthdate'])) :
      null,
      specialty: json['specialty'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      cityOfWork: json['cityOfWork'] ?? '',
      email: json['email'] ?? '',
      googleEmail: json['googleEmail'] ?? '',
      vatNumber: json['vatNumber'] ?? '',
      fiscalCode: json['fiscalCode'] ?? '',
      status: json['status'] ?? 'pending',
      requestedAt: json['requestedAt'] != null ?
      (json['requestedAt'] is Timestamp ?
      (json['requestedAt'] as Timestamp).toDate() :
      DateTime.parse(json['requestedAt'])) :
      DateTime.now(),
      processedAt: json['processedAt'] != null ?
      (json['processedAt'] is Timestamp ?
      (json['processedAt'] as Timestamp).toDate() :
      DateTime.parse(json['processedAt'])) :
      null,
      deleteAt: json['deleteAt'] != null ?
      (json['deleteAt'] is Timestamp ?
      (json['deleteAt'] as Timestamp).toDate() :
      DateTime.parse(json['deleteAt'])) :
      null,
      temporaryPassword: json['temporaryPassword'],
      rejectionReason: json['rejectionReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'name': name,
      'surname': surname,
      'sex': sex,
      'birthdate': birthdate?.toIso8601String(),
      'specialty': specialty,
      'phoneNumber': phoneNumber,
      'cityOfWork': cityOfWork,
      'email': email,
      'googleEmail': googleEmail,
      'vatNumber': vatNumber,
      'fiscalCode': fiscalCode,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'deleteAt': deleteAt?.toIso8601String(),
      'temporaryPassword': temporaryPassword,
      'rejectionReason': rejectionReason,
    };
  }

  // Create a copy with updated fields
  SignupRequest copyWith({
    String? id,
    String? role,
    String? name,
    String? surname,
    String? sex,
    DateTime? birthdate,
    String? specialty,
    String? phoneNumber,
    String? cityOfWork,
    String? email,
    String? googleEmail,
    String? vatNumber,
    String? fiscalCode,
    String? status,
    DateTime? requestedAt,
    DateTime? processedAt,
    DateTime? deleteAt,
  }) {
    return SignupRequest(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      sex: sex ?? this.sex,
      birthdate: birthdate ?? this.birthdate,
      specialty: specialty ?? this.specialty,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cityOfWork: cityOfWork ?? this.cityOfWork,
      email: email ?? this.email,
      googleEmail: googleEmail ?? this.googleEmail,
      vatNumber: vatNumber ?? this.vatNumber,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      deleteAt: deleteAt ?? this.deleteAt,
    );
  }
}