import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  // Role constants
  static const String ROLE_DOCTOR = "DOCTOR";
  static const String ROLE_CLINIC = "CLINIC";

  final String id;
  final String name;
  final String surname;
  final String sex;
  final String phoneNumber;
  final DateTime birthdate;
  final String specialty;
  final String email;
  final String googleEmail; // Added Google email from signup request
  final String placeOfWork;
  final String cityOfWork;
  final String areaOfInterest;
  final String role; // Used with ROLE_DOCTOR or ROLE_CLINIC
  final String licenseNumber;
  final String vatNumber;
  final String fiscalCode; // Added fiscal code from signup request
  final double hourlyFees;
  final bool isDoctor;
  final bool requiredPasswordChange;
  final DateTime? signupApprovalDate; // Added to track when account was created
  final String? signupRequestId; // Reference to original signup request
  final String profilePictureUrl; // Added profile picture URL

  Doctor({
    required this.id,
    required this.name,
    required this.surname,
    required this.sex,
    required this.phoneNumber,
    required this.birthdate,
    required this.specialty,
    required this.email,
    this.googleEmail = '', // Default to empty string
    required this.placeOfWork,
    required this.cityOfWork,
    required this.areaOfInterest,
    required this.role,
    required this.licenseNumber,
    required this.vatNumber,
    this.fiscalCode = '', // Default to empty string
    required this.hourlyFees,
    required this.isDoctor,
    this.requiredPasswordChange = false,
    this.signupApprovalDate,
    this.signupRequestId,
    this.profilePictureUrl = '', // Default to empty string
  });

  // Factory constructor to create a Doctor object from a JSON map
  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      sex: json['sex'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      birthdate: json['birthdate'] != null ?
      (json['birthdate'] is Timestamp ?
      (json['birthdate'] as Timestamp).toDate() :
      (json['birthdate'] is String ?
      DateTime.parse(json['birthdate']) :
      json['birthdate'] as DateTime)) :
      DateTime.now(),
      specialty: json['specialty'] ?? '',
      email: json['email'] ?? '',
      googleEmail: json['googleEmail'] ?? '',
      placeOfWork: json['placeOfWork'] ?? '',
      cityOfWork: json['cityOfWork'] ?? '',
      areaOfInterest: json['areaOfInterest'] ?? '',
      role: json['role'] ?? ROLE_DOCTOR,
      licenseNumber: json['licenseNumber'] ?? '',
      vatNumber: json['vatNumber'] ?? '',
      fiscalCode: json['fiscalCode'] ?? '',
      hourlyFees: (json['hourlyFees'] ?? 0.0).toDouble(),
      isDoctor: json['isDoctor'] ?? false,
      requiredPasswordChange: json['requiredPasswordChange'] ?? false,
      signupApprovalDate: json['signupApprovalDate'] != null ?
      (json['signupApprovalDate'] is Timestamp ?
      (json['signupApprovalDate'] as Timestamp).toDate() :
      (json['signupApprovalDate'] is String ?
      DateTime.parse(json['signupApprovalDate']) :
      json['signupApprovalDate'] as DateTime)) :
      null,
      signupRequestId: json['signupRequestId'],
      profilePictureUrl: json['profilePictureUrl'] ?? '',
    );
  }

  // Method to convert a Doctor object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'sex': sex,
      'phoneNumber': phoneNumber,
      'birthdate': birthdate.toIso8601String(),
      'specialty': specialty,
      'email': email,
      'googleEmail': googleEmail, // Include Google email
      'placeOfWork': placeOfWork,
      'cityOfWork': cityOfWork,
      'areaOfInterest': areaOfInterest,
      'role': role,
      'licenseNumber': licenseNumber,
      'vatNumber': vatNumber,
      'fiscalCode': fiscalCode, // Include fiscal code
      'hourlyFees': hourlyFees,
      'isDoctor': isDoctor,
      'requiredPasswordChange': requiredPasswordChange,
      'signupApprovalDate': signupApprovalDate?.toIso8601String(),
      'signupRequestId': signupRequestId,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  // Helper methods to check role
  bool isClinic() {
    return role == ROLE_CLINIC;
  }

  bool isRoleDoctor() {
    return role == ROLE_DOCTOR;
  }

  // Create a copy with updated fields
  Doctor copyWith({
    String? id,
    String? name,
    String? surname,
    String? sex,
    String? phoneNumber,
    DateTime? birthdate,
    String? specialty,
    String? email,
    String? googleEmail,
    String? password,
    String? placeOfWork,
    String? cityOfWork,
    String? areaOfInterest,
    String? role,
    String? licenseNumber,
    String? vatNumber,
    String? fiscalCode,
    double? hourlyFees,
    bool? isDoctor,
    bool? requiredPasswordChange,
    DateTime? signupApprovalDate,
    String? signupRequestId,
    String? profilePictureUrl,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      sex: sex ?? this.sex,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthdate: birthdate ?? this.birthdate,
      specialty: specialty ?? this.specialty,
      email: email ?? this.email,
      googleEmail: googleEmail ?? this.googleEmail,
      placeOfWork: placeOfWork ?? this.placeOfWork,
      cityOfWork: cityOfWork ?? this.cityOfWork,
      areaOfInterest: areaOfInterest ?? this.areaOfInterest,
      role: role ?? this.role,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      hourlyFees: hourlyFees ?? this.hourlyFees,
      isDoctor: isDoctor ?? this.isDoctor,
      requiredPasswordChange: requiredPasswordChange ?? this.requiredPasswordChange,
      signupApprovalDate: signupApprovalDate ?? this.signupApprovalDate,
      signupRequestId: signupRequestId ?? this.signupRequestId,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }
}