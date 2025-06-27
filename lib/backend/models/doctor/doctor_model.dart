import 'package:cloud_firestore/cloud_firestore.dart';

//Il ruolo in questione in FHIR 5.0 è "Practitioner" per indicare un professionista sanitario coinvolto in un processo healthcare o in un servizio healthcare collegato
// Quando invece si parla di ruolo, specialità, sede di lavoro, tariffe siamo sull'entità "PractionerRole" che è un'estensione di "Practitioner" e che definisce il ruolo specifico del professionista sanitario in un contesto sanitario
// Infine per descrivere dove il practioner esercita la propria attività e quindi per descrivere la struttura dobbiamo lavorare su Organization

class Doctor { //Practioner
  // Role constants
  static const String ROLE_DOCTOR = "DOCTOR";
  static const String ROLE_CLINIC = "CLINIC";
  static const String ROLE_CENTRO_ACUSTICO = "CENTRO_ACUSTICO";
  static const String ROLE_TECNICO_AUDIOPROTESISTA = "TECNICO_AUDIOPROTESISTA";
  static const String ROLE_CENTRO_OTOLOGIA = "CENTRO_OTOLOGIA";
  static const String ROLE_MEDICO = "MEDICO";

  final String id; // FHIR: Practioner.id e Practitioner.identifier[0]
  final String name; // Practitioner.name[0].given, .family
  final String surname; // concatenated with name
  final String sex; // Practitioner.gender
  final String phoneNumber; // Practitioner.telecom[system=phone
  final DateTime birthdate;
  final String email; // Practitioner.telecom[system=email]
  final String googleEmail; // Added Google email from signup request
  final String areaOfInterest; // Estensione di PractitionerRole.specialty
  final String role; // Used with ROLE_DOCTOR or ROLE_CLINIC. Vanno separati in due entità diverse Organization e Practitioner
  final String licenseNumber; // Practitioner.qualification.identifier
  final String vatNumber; //Practitioner.identifier[system=vatNumber]
  final String fiscalCode; // Added fiscal code from signup request
  final double hourlyFees; // Potrebbe servire una nuova estensione
  final bool isDoctor; // lo deriviamo da practionerRole.code[system=doctor] possiamo eliminarlo
  final bool requiredPasswordChange;
  final DateTime? signupApprovalDate; // Added to track when account was created
  final String? signupRequestId; // Reference to original signup request
  final String profilePictureUrl; // Added profile picture URL in FHIR Practitioner.photo[0].url

  // New FHIR-compliant fields
  final bool isActive; // FHIR active boolean
  final bool isAlive; // FHIR deceased (da capire come integrare)
  final String address; //FHIR address --> segue integrazione con google maps
  final List<String> languagesSpoken; // FHIR communication
  final DateTime? qualificationValidity; // FHIR qualification.validity
  final String issuer; // FHIR issuer --> emittente per la qualifica del professionista

  /// Da inserire nel PractiotionerRole
  final String specialty; // PractitionerRole.specialty[0]. La specializzazione è legata al ruolo svolto in un dato contesto. Questo campo va approfondito con entità PractionerRole
  final String placeOfWork; // PractitionerRole.location → Location.address
  final String cityOfWork; // PractitionerRole.location → Location.address.city
  final DateTime? organizationPeriodValidity; // FHIR PractiotionerRole.period
  final String organization; // FHIR organization

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
    // New fields with defaults
    this.isActive = true,
    this.isAlive = true,
    this.address = '',
    this.languagesSpoken = const [],
    this.qualificationValidity,
    this.issuer = '',
    this.organizationPeriodValidity,
    this.organization = '',
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
      // New fields with more robust handling for existing users
      isActive: json['isActive'] ?? true,
      isAlive: json['isAlive'] ?? true,
      address: json['address'] ?? 'To be updated',
      languagesSpoken: json['languagesSpoken'] != null
          ? (json['languagesSpoken'] is List
          ? List<String>.from(json['languagesSpoken'])
          : ['To be updated'])
          : ['To be updated'],
      qualificationValidity: json['qualificationValidity'] != null ?
      (json['qualificationValidity'] is Timestamp ?
      (json['qualificationValidity'] as Timestamp).toDate() :
      (json['qualificationValidity'] is String ?
      DateTime.parse(json['qualificationValidity']) :
      json['qualificationValidity'] as DateTime)) :
      null,
      issuer: json['issuer'] ?? '',
      organizationPeriodValidity: json['organizationPeriodValidity'] != null ?
      (json['organizationPeriodValidity'] is Timestamp ?
      (json['organizationPeriodValidity'] as Timestamp).toDate() :
      (json['organizationPeriodValidity'] is String ?
      DateTime.parse(json['organizationPeriodValidity']) :
      json['organizationPeriodValidity'] as DateTime)) :
      null,
      organization: json['organization'] ?? 'To be updated',
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
      // New fields
      'isActive': isActive,
      'isAlive': isAlive,
      'address': address,
      'languagesSpoken': languagesSpoken,
      'qualificationValidity': qualificationValidity?.toIso8601String(),
      'issuer': issuer,
      'organizationPeriodValidity': organizationPeriodValidity?.toIso8601String(),
      'organization': organization,
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
    // New fields
    bool? isActive,
    bool? isAlive,
    String? address,
    List<String>? languagesSpoken,
    DateTime? qualificationValidity,
    String? issuer,
    DateTime? organizationPeriodValidity,
    String? organization,
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
      // New fields
      isActive: isActive ?? this.isActive,
      isAlive: isAlive ?? this.isAlive,
      address: address ?? this.address,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      qualificationValidity: qualificationValidity ?? this.qualificationValidity,
      issuer: issuer ?? this.issuer,
      organizationPeriodValidity: organizationPeriodValidity ?? this.organizationPeriodValidity,
      organization: organization ?? this.organization,
    );
  }
}