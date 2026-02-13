import 'package:cloud_firestore/cloud_firestore.dart';
import './doctor/sign_up_data.dart';

/// UPDATED: SignupRequest model with multiple roles and professional registration support + hourlyFees
class SignupRequest {
  final String id;

  // UPDATED: Support for multiple roles with backward compatibility
  final List<String> roles; // NEW: Multiple roles support
  final String? role; // LEGACY: Kept for backward compatibility

  final String name;
  final String surname;
  final String sex;
  final DateTime? birthdate;
  final String specialty;
  final String phoneNumber;
  final String cityOfWork;
  final String countryOfWork; // NEW: Country of work
  final String email;
  final String vatNumber;
  final String fiscalCode;

  // Existing fields
  final String address;
  final List<String> languagesSpoken;

  // NEW: Professional registration fields
  final String? numeroIscrizioneAlbo; // For nutritionists, psychologists
  final String? numeroIscrizioneEnte; // For personal trainers
  final String issuer; // Professional qualification issuer
  final String? areaOfInterest; // Area of professional interest
  final DateTime? qualificationValidity; // Qualification expiry date

  // NEW: Hourly fees field
  final double hourlyFees; // Professional hourly rate in Euros

  // First visit duration in minutes (default 60)
  final int firstVisitDurationMinutes;

  // First visit modality (default 'in_person')
  final String firstVisitModality;

  // Status fields - UNCHANGED
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? deleteAt;
  final String? temporaryPassword;
  final String? rejectionReason;

  SignupRequest({
    required this.id,
    this.roles = const [], // NEW: Multiple roles with default empty list
    this.role, // LEGACY: Single role for backward compatibility
    required this.name,
    required this.surname,
    required this.sex,
    this.birthdate,
    required this.specialty,
    required this.phoneNumber,
    required this.cityOfWork,
    this.countryOfWork = 'Italy', // NEW: Default country
    required this.email,
    required this.vatNumber,
    required this.fiscalCode,

    // Existing fields with defaults
    this.address = '',
    this.languagesSpoken = const [],

    // NEW: Professional registration fields with defaults
    this.numeroIscrizioneAlbo,
    this.numeroIscrizioneEnte,
    this.issuer = '',
    this.areaOfInterest,
    this.qualificationValidity,

    // NEW: Hourly fees with default
    this.hourlyFees = 0.0,

    // First visit duration (default 60 minutes)
    this.firstVisitDurationMinutes = 60,

    // First visit modality
    this.firstVisitModality = 'in_person',

    // Status fields - UNCHANGED
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.deleteAt,
    this.temporaryPassword,
    this.rejectionReason,
  });

  // UPDATED: Factory constructor with enhanced parsing for new fields including hourlyFees
  factory SignupRequest.fromJson(Map<String, dynamic> json, String docId) {
    // Handle both old single role and new multiple roles format
    List<String> parsedRoles = [];
    String? legacyRole;

    if (json['roles'] != null && json['roles'] is List) {
      // NEW: Multiple roles format
      parsedRoles = List<String>.from(json['roles']);
    } else if (json['role'] != null) {
      // LEGACY: Single role format
      legacyRole = json['role'] as String;
      parsedRoles = [legacyRole]; // Convert single role to list
    }

    // NEW: Parse hourly fees with fallback to 0.0
    double parsedHourlyFees = 0.0;
    if (json['hourlyFees'] != null) {
      if (json['hourlyFees'] is double) {
        parsedHourlyFees = json['hourlyFees'];
      } else if (json['hourlyFees'] is int) {
        parsedHourlyFees = (json['hourlyFees'] as int).toDouble();
      } else if (json['hourlyFees'] is String) {
        try {
          parsedHourlyFees = double.parse(json['hourlyFees']);
        } catch (e) {
          parsedHourlyFees = 0.0;
        }
      }
    }

    // Parse firstVisitDurationMinutes (default 60)
    int parsedFirstVisitDuration = 60;
    if (json['firstVisitDurationMinutes'] != null) {
      if (json['firstVisitDurationMinutes'] is int) {
        parsedFirstVisitDuration = json['firstVisitDurationMinutes'];
      } else if (json['firstVisitDurationMinutes'] is double) {
        parsedFirstVisitDuration =
            (json['firstVisitDurationMinutes'] as double).toInt();
      } else if (json['firstVisitDurationMinutes'] is String) {
        parsedFirstVisitDuration = int.tryParse(
              json['firstVisitDurationMinutes'],
            ) ??
            60;
      }
    }

    // Parse firstVisitModality (default 'in_person')
    final parsedModality = json['firstVisitModality'] as String? ?? 'in_person';

    return SignupRequest(
      id: docId,
      roles: parsedRoles, // NEW: Multiple roles
      role: legacyRole ??
          (parsedRoles.isNotEmpty
              ? parsedRoles.first
              : null), // LEGACY: Backward compatibility
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      sex: json['sex'] ?? '',
      birthdate: json['birthdate'] != null
          ? (json['birthdate'] is Timestamp
              ? (json['birthdate'] as Timestamp).toDate()
              : DateTime.parse(json['birthdate']))
          : null,
      specialty: json['specialty'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      cityOfWork: json['cityOfWork'] ?? '',
      countryOfWork: json['countryOfWork'] ?? 'Italy', // NEW: Country field
      email: json['email'] ?? '',
      vatNumber: json['vatNumber'] ?? '',
      fiscalCode: json['fiscalCode'] ?? '',

      // Existing fields
      address: json['address'] ?? '',
      languagesSpoken: json['languagesSpoken'] != null
          ? List<String>.from(json['languagesSpoken'])
          : [],

      // NEW: Professional registration fields
      numeroIscrizioneAlbo: json['numero_iscrizione_albo'] as String?,
      numeroIscrizioneEnte: json['numero_iscrizione_ente'] as String?,
      issuer: json['issuer'] ?? '',
      areaOfInterest: json['areaOfInterest'] as String?,
      qualificationValidity: json['qualificationValidity'] != null
          ? (json['qualificationValidity'] is Timestamp
              ? (json['qualificationValidity'] as Timestamp).toDate()
              : DateTime.parse(json['qualificationValidity']))
          : null,

      // NEW: Hourly fees
      hourlyFees: parsedHourlyFees,

      // First visit duration
      firstVisitDurationMinutes: parsedFirstVisitDuration,

      // First visit modality
      firstVisitModality: parsedModality,

      // Status fields - UNCHANGED
      status: json['status'] ?? 'pending',
      requestedAt: json['requestedAt'] != null
          ? (json['requestedAt'] is Timestamp
              ? (json['requestedAt'] as Timestamp).toDate()
              : DateTime.parse(json['requestedAt']))
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? (json['processedAt'] is Timestamp
              ? (json['processedAt'] as Timestamp).toDate()
              : DateTime.parse(json['processedAt']))
          : null,
      deleteAt: json['deleteAt'] != null
          ? (json['deleteAt'] is Timestamp
              ? (json['deleteAt'] as Timestamp).toDate()
              : DateTime.parse(json['deleteAt']))
          : null,
      temporaryPassword: json['temporaryPassword'],
      rejectionReason: json['rejectionReason'],
    );
  }

  // UPDATED: Enhanced toJson with hourlyFees
  Map<String, dynamic> toJson() {
    return {
      // UPDATED: Include both formats for compatibility
      'roles': roles, // NEW: Multiple roles
      'role': role ??
          (roles.isNotEmpty
              ? roles.first
              : null), // LEGACY: Single role for backward compatibility

      'name': name,
      'surname': surname,
      'sex': sex,
      'birthdate': birthdate?.toIso8601String(),
      'specialty': specialty,
      'phoneNumber': phoneNumber,
      'cityOfWork': cityOfWork,
      'countryOfWork': countryOfWork, // NEW: Country field
      'email': email,
      'vatNumber': vatNumber,
      'fiscalCode': fiscalCode,

      // Existing fields
      'address': address,
      'languagesSpoken': languagesSpoken,

      // NEW: Professional registration fields
      'numero_iscrizione_albo': numeroIscrizioneAlbo,
      'numero_iscrizione_ente': numeroIscrizioneEnte,
      'issuer': issuer,
      'areaOfInterest': areaOfInterest,
      'qualificationValidity': qualificationValidity?.toIso8601String(),

      // NEW: Hourly fees
      'hourlyFees': hourlyFees,

      // First visit duration
      'firstVisitDurationMinutes': firstVisitDurationMinutes,

      // First visit modality
      'firstVisitModality': firstVisitModality,

      // Status fields - UNCHANGED
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'deleteAt': deleteAt?.toIso8601String(),
      'temporaryPassword': temporaryPassword,
      'rejectionReason': rejectionReason,
    };
  }

  // UPDATED: Enhanced copyWith method with hourlyFees
  SignupRequest copyWith({
    String? id,
    List<String>? roles, // NEW: Multiple roles
    String? role, // LEGACY: Single role
    String? name,
    String? surname,
    String? sex,
    DateTime? birthdate,
    String? specialty,
    String? phoneNumber,
    String? cityOfWork,
    String? countryOfWork, // NEW: Country field
    String? email,
    String? vatNumber,
    String? fiscalCode,

    // Existing fields
    String? address,
    List<String>? languagesSpoken,

    // NEW: Professional registration fields
    String? numeroIscrizioneAlbo,
    String? numeroIscrizioneEnte,
    String? issuer,
    String? areaOfInterest,
    DateTime? qualificationValidity,

    // NEW: Hourly fees
    double? hourlyFees,

    // First visit duration
    int? firstVisitDurationMinutes,

    // First visit modality
    String? firstVisitModality,

    // Status fields
    String? status,
    DateTime? requestedAt,
    DateTime? processedAt,
    DateTime? deleteAt,
    String? temporaryPassword,
    String? rejectionReason,
  }) {
    return SignupRequest(
      id: id ?? this.id,
      roles: roles ?? this.roles, // NEW: Multiple roles
      role: role ?? this.role, // LEGACY: Single role
      name: name ?? this.name,
      surname: surname ?? this.surname,
      sex: sex ?? this.sex,
      birthdate: birthdate ?? this.birthdate,
      specialty: specialty ?? this.specialty,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cityOfWork: cityOfWork ?? this.cityOfWork,
      countryOfWork: countryOfWork ?? this.countryOfWork, // NEW: Country field
      email: email ?? this.email,
      vatNumber: vatNumber ?? this.vatNumber,
      fiscalCode: fiscalCode ?? this.fiscalCode,

      // Existing fields
      address: address ?? this.address,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,

      // NEW: Professional registration fields
      numeroIscrizioneAlbo: numeroIscrizioneAlbo ?? this.numeroIscrizioneAlbo,
      numeroIscrizioneEnte: numeroIscrizioneEnte ?? this.numeroIscrizioneEnte,
      issuer: issuer ?? this.issuer,
      areaOfInterest: areaOfInterest ?? this.areaOfInterest,
      qualificationValidity:
          qualificationValidity ?? this.qualificationValidity,

      // NEW: Hourly fees
      hourlyFees: hourlyFees ?? this.hourlyFees,

      // First visit duration
      firstVisitDurationMinutes:
          firstVisitDurationMinutes ?? this.firstVisitDurationMinutes,

      // First visit modality
      firstVisitModality: firstVisitModality ?? this.firstVisitModality,

      // Status fields
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      deleteAt: deleteAt ?? this.deleteAt,
      temporaryPassword: temporaryPassword ?? this.temporaryPassword,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // NEW: Helper methods for role checking
  bool hasRole(String roleToCheck) => roles.contains(roleToCheck);
  bool get isNutritionist => hasRole('NUTRITIONIST');
  bool get isPersonalTrainer => hasRole('PERSONAL TRAINER');
  bool get isPsychologist => hasRole('PSYCHOLOGIST');

  // NEW: Get appropriate registration number based on roles
  String? get professionalRegistrationNumber {
    if ((isNutritionist || isPsychologist) && numeroIscrizioneAlbo != null) {
      return numeroIscrizioneAlbo;
    } else if (isPersonalTrainer && numeroIscrizioneEnte != null) {
      return numeroIscrizioneEnte;
    }
    return null;
  }

  // NEW: Check if this request requires professional registration
  bool get requiresProfessionalRegistration =>
      isNutritionist || isPsychologist || isPersonalTrainer;

  // NEW: Get role-specific registration type
  String get registrationType {
    if (isNutritionist || isPsychologist) {
      return 'albo';
    } else if (isPersonalTrainer) {
      return 'ente';
    }
    return 'none';
  }

  // NEW: Get user-friendly role names
  List<String> get roleDisplayNames {
    const roleMap = {
      'NUTRITIONIST': 'Nutrizionista',
      'PERSONAL TRAINER': 'Personal Trainer',
      'PSYCHOLOGIST': 'Psicologo',
    };
    return roles.map((role) => roleMap[role] ?? role).toList();
  }

  // NEW: Check if hourly fees is set (non-zero)
  bool get hasHourlyFeesSet => hourlyFees > 0;

  // NEW: Get formatted hourly fees for display
  String get formattedHourlyFees {
    if (hourlyFees == 0.0) {
      return 'Non specificato';
    } else if (hourlyFees == hourlyFees.roundToDouble()) {
      return '€${hourlyFees.round()}';
    } else {
      return '€${hourlyFees.toStringAsFixed(2)}';
    }
  }

  // UPDATED: Validation helper with hourlyFees
  bool get hasValidProfessionalRegistration {
    if (!requiresProfessionalRegistration) return true;

    if ((isNutritionist || isPsychologist) &&
        (numeroIscrizioneAlbo == null || numeroIscrizioneAlbo!.isEmpty)) {
      return false;
    }

    if (isPersonalTrainer &&
        (numeroIscrizioneEnte == null || numeroIscrizioneEnte!.isEmpty)) {
      return false;
    }

    if (requiresProfessionalRegistration && issuer.isEmpty) {
      return false;
    }

    return true;
  }

  // UPDATED: Get validation errors for this signup request including hourlyFees
  List<String> get validationErrors {
    final errors = <String>[];

    if (roles.isEmpty) errors.add('At least one role must be selected');
    if (name.isEmpty) errors.add('Name is required');
    if (phoneNumber.isEmpty) errors.add('Phone number is required');
    if (email.isEmpty) errors.add('Email is required');
    if (fiscalCode.isEmpty) errors.add('Fiscal code is required');
    if (cityOfWork.isEmpty) errors.add('City of work is required');

    // NEW: Hourly fees validation
    if (hourlyFees < 0) errors.add('Hourly fees cannot be negative');
    if (hourlyFees > 1000) errors.add('Hourly fees cannot exceed €1000');

    // Role-specific validation
    if ((isNutritionist || isPsychologist) &&
        (numeroIscrizioneAlbo == null || numeroIscrizioneAlbo!.isEmpty)) {
      final roleNames = <String>[];
      if (isNutritionist) roleNames.add('Nutritionist');
      if (isPsychologist) roleNames.add('Psychologist');
      errors.add(
          'Professional registration number (albo) is required for ${roleNames.join(" and ")} role(s)');
    }

    if (isPersonalTrainer &&
        (numeroIscrizioneEnte == null || numeroIscrizioneEnte!.isEmpty)) {
      errors.add(
          'Professional registration number (ente) is required for Personal Trainer role');
    }

    if (requiresProfessionalRegistration && issuer.isEmpty) {
      errors.add('Professional qualification issuer is required');
    }

    return errors;
  }

  // UPDATED: Create from SignupData with hourlyFees
  factory SignupRequest.fromSignupData(
    SignupData signupData,
    String requestId,
    String status,
  ) {
    return SignupRequest(
      id: requestId,
      roles: signupData.roles,
      role: signupData.roles.isNotEmpty
          ? signupData.roles.first
          : null, // Backward compatibility
      name: signupData.name,
      surname: signupData.surname,
      sex: signupData.sex,
      birthdate: signupData.birthdate,
      specialty: signupData.specialty ?? '',
      phoneNumber: signupData.phoneNumber,
      cityOfWork: signupData.cityOfWork,
      countryOfWork: signupData.countryOfWork,
      email: signupData.email,
      vatNumber: signupData.vatNumber,
      fiscalCode: signupData.fiscalCode,
      address: signupData.address,
      languagesSpoken: signupData.languagesSpoken,
      numeroIscrizioneAlbo: signupData.numero_iscrizione_albo,
      numeroIscrizioneEnte: signupData.numero_iscrizione_ente,
      issuer: signupData.issuer,
      areaOfInterest: signupData.areaOfInterest,
      qualificationValidity: signupData.qualificationValidity,
      // NEW: Include hourly fees from signup data
      hourlyFees: signupData.hourlyFees,
      firstVisitDurationMinutes: signupData.firstVisitDurationMinutes,
      firstVisitModality: signupData.firstVisitModality,
      status: status,
      requestedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SignupRequest{id: $id, roles: $roles, '
        'name: $name, surname: $surname, '
        'email: $email, status: $status, '
        'hourlyFees: $hourlyFees, '
        'firstVisitDurationMinutes: '
        '$firstVisitDurationMinutes, '
        'firstVisitModality: '
        '$firstVisitModality}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignupRequest &&
        other.id == id &&
        other.roles.toString() == roles.toString() &&
        other.name == name &&
        other.surname == surname &&
        other.email == email &&
        other.hourlyFees == hourlyFees &&
        other.firstVisitDurationMinutes == firstVisitDurationMinutes &&
        other.firstVisitModality == firstVisitModality;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        roles.hashCode ^
        name.hashCode ^
        surname.hashCode ^
        email.hashCode ^
        hourlyFees.hashCode ^
        firstVisitDurationMinutes.hashCode ^
        firstVisitModality.hashCode;
  }
}
