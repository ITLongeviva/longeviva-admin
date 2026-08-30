import 'package:cloud_firestore/cloud_firestore.dart';

//Il ruolo in questione in FHIR 5.0 è "Practitioner" per indicare un professionista sanitario coinvolto in un processo healthcare o in un servizio healthcare collegato
// Quando invece si parla di ruolo, specialità, sede di lavoro, tariffe siamo sull'entità "PractionerRole" che è un'estensione di "Practitioner" e che definisce il ruolo specifico del professionista sanitario in un contesto sanitario
// Infine per descrivere dove il practioner esercita la propria attività e quindi per descrivere la struttura dobbiamo lavorare su Organization

class Doctor { //Practioner
  // Available roles
  static const List<String> availableRoles = [
    "NUTRITIONIST",
    "PERSONAL TRAINER",
    "PSYCHOLOGIST"
  ];

  // Role constants
  static const String ROLE_NUTRITIONIST = "NUTRITIONIST";
  static const String ROLE_PERSONAL_TRAINER = "PERSONAL TRAINER";
  static const String ROLE_PSYCHOLOGIST = "PSYCHOLOGIST";

  final String id; // FHIR: Practioner.id e Practitioner.identifier[0]
  final String name; // Practitioner.name[0].given, .family
  final String surname; // concatenated with name
  final String sex; // Practitioner.gender
  final String phoneNumber; // Practitioner.telecom[system=phone]
  final DateTime birthdate; // Data di nascita Doctor
  final String address; // FHIR address --> segue integrazione con google maps
  final String cityOfWork; // PractitionerRole.location → Location.address.city
  final String countryOfWork; // Country of work
  final String fiscalCode; // Added fiscal code from signup request
  final String email; // Practitioner.telecom[system=email]
  final List<String> roles; // Multiple roles support
  final String vatNumber; //Practitioner.identifier[system=vatNumber]
  final double hourlyFees; // Potrebbe servire una nuova estensione
  final bool requiredPasswordChange;
  final bool hasCompletedServiceSetup;
  final DateTime? signupApprovalDate; // Added to track when account was created
  final String? signupRequestId; // Reference to original signup request
  final String profilePictureUrl; // Added profile picture URL in FHIR Practitioner.photo[0].url

  // New FHIR-compliant fields
  final bool isActive; // FHIR active boolean
  final bool isAlive; // FHIR deceased (da capire come integrare)
  final List<String> languagesSpoken; // FHIR communication

  /// CAMPI LEGATI ALLA PROFESSIONE
  // ------------------------------
  // SE BIOLOGO O NUTRIZIONISTA O DIETISTA O PSICOLOGO
  final String? numero_iscrizione_albo; // Practitioner.qualification.identifier
  // SE PERSONAL TRAINER
  final String? numero_iscrizione_ente;
  // ------------------------------
  final String issuer; // FHIR issuer --> ente per la qualifica del professionista
  // Certificazione (formato corrente del form di registrazione)
  // 'universita' | 'ente' | 'attestato'
  final String? registrationEntityType;
  final String? registrationValue; // Ente/istituto che rilascia il titolo
  final DateTime? qualificationValidity; // FHIR qualification.validity
  final String? specialty; // PractitionerRole.specialty[0]. La specializzazione è legata al ruolo svolto in un dato contesto. Questo campo va approfondito con entità PractionerRole
  final String? areaOfInterest; // Estensione di PractitionerRole.specialty

  /// Policy acceptance audit fields
  final DateTime? termsOfServiceAcceptedAt; // Timestamp when terms of service were accepted
  final DateTime? privacyPolicyAcceptedAt; // Timestamp when privacy policy was accepted

  Doctor({
    required this.id,
    required this.name,
    required this.surname,
    required this.sex,
    required this.phoneNumber,
    required this.birthdate,
    required this.address,
    required this.cityOfWork,
    required this.countryOfWork,
    required this.fiscalCode,
    required this.email,
    required this.roles,
    required this.vatNumber,
    required this.hourlyFees,
    this.requiredPasswordChange = false,
    this.hasCompletedServiceSetup = false,
    this.signupApprovalDate,
    this.signupRequestId,
    this.profilePictureUrl = '', // Default to empty string
    // New fields with defaults
    this.isActive = true,
    this.isAlive = true,
    this.languagesSpoken = const [],
    this.numero_iscrizione_albo,
    this.numero_iscrizione_ente,
    this.issuer = '',
    this.registrationEntityType,
    this.registrationValue,
    this.qualificationValidity,
    this.specialty,
    this.areaOfInterest,
    // Policy acceptance fields
    this.termsOfServiceAcceptedAt,
    this.privacyPolicyAcceptedAt,
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
      address: json['address'] ?? '',
      cityOfWork: json['cityOfWork'] ?? '',
      countryOfWork: json['countryOfWork'] ?? '',
      fiscalCode: json['fiscalCode'] ?? '',
      email: json['email'] ?? '',
      roles: json['roles'] != null
          ? (json['roles'] is List
          ? List<String>.from(json['roles'])
          : [json['roles'].toString()])
          : [],
      vatNumber: json['vatNumber'] ?? '',
      hourlyFees: (json['hourlyFees'] ?? 0.0).toDouble(),
      requiredPasswordChange: json['requiredPasswordChange'] ?? false,
      hasCompletedServiceSetup:
          json['hasCompletedServiceSetup'] ?? false,
      signupApprovalDate: json['signupApprovalDate'] != null ?
      (json['signupApprovalDate'] is Timestamp ?
      (json['signupApprovalDate'] as Timestamp).toDate() :
      (json['signupApprovalDate'] is String ?
      DateTime.parse(json['signupApprovalDate']) :
      json['signupApprovalDate'] as DateTime)) :
      null,
      signupRequestId: json['signupRequestId'],
      profilePictureUrl: json['profilePictureUrl'] ?? '',
      // New fields with robust handling
      isActive: json['isActive'] ?? true,
      isAlive: json['isAlive'] ?? true,
      languagesSpoken: json['languagesSpoken'] != null
          ? (json['languagesSpoken'] is List
          ? List<String>.from(json['languagesSpoken'])
          : [])
          : [],
      numero_iscrizione_albo: json['numero_iscrizione_albo'],
      numero_iscrizione_ente: json['numero_iscrizione_ente'],
      issuer: json['issuer'] ?? '',
      registrationEntityType: json['registrationEntityType'],
      registrationValue: json['registrationValue'],
      qualificationValidity: json['qualificationValidity'] != null ?
      (json['qualificationValidity'] is Timestamp ?
      (json['qualificationValidity'] as Timestamp).toDate() :
      (json['qualificationValidity'] is String ?
      DateTime.parse(json['qualificationValidity']) :
      json['qualificationValidity'] as DateTime)) :
      null,
      specialty: json['specialty'],
      areaOfInterest: json['areaOfInterest'],
      // Policy acceptance fields with proper timestamp handling
      termsOfServiceAcceptedAt: json['termsOfServiceAcceptedAt'] != null ?
      (json['termsOfServiceAcceptedAt'] is Timestamp ?
      (json['termsOfServiceAcceptedAt'] as Timestamp).toDate() :
      (json['termsOfServiceAcceptedAt'] is String ?
      DateTime.parse(json['termsOfServiceAcceptedAt']) :
      json['termsOfServiceAcceptedAt'] as DateTime)) :
      null,
      privacyPolicyAcceptedAt: json['privacyPolicyAcceptedAt'] != null ?
      (json['privacyPolicyAcceptedAt'] is Timestamp ?
      (json['privacyPolicyAcceptedAt'] as Timestamp).toDate() :
      (json['privacyPolicyAcceptedAt'] is String ?
      DateTime.parse(json['privacyPolicyAcceptedAt']) :
      json['privacyPolicyAcceptedAt'] as DateTime)) :
      null,
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
      'birthdate': Timestamp.fromDate(birthdate),
      'address': address,
      'cityOfWork': cityOfWork,
      'countryOfWork': countryOfWork,
      'fiscalCode': fiscalCode,
      'email': email,
      'roles': roles,
      'vatNumber': vatNumber,
      'hourlyFees': hourlyFees,
      'requiredPasswordChange': requiredPasswordChange,
      'hasCompletedServiceSetup':
          hasCompletedServiceSetup,
      'signupApprovalDate': signupApprovalDate != null ? Timestamp.fromDate(signupApprovalDate!) : null,
      'signupRequestId': signupRequestId,
      'profilePictureUrl': profilePictureUrl,
      // New fields
      'isActive': isActive,
      'isAlive': isAlive,
      'languagesSpoken': languagesSpoken,
      'numero_iscrizione_albo': numero_iscrizione_albo,
      'numero_iscrizione_ente': numero_iscrizione_ente,
      'issuer': issuer,
      'registrationEntityType': registrationEntityType,
      'registrationValue': registrationValue,
      'qualificationValidity': qualificationValidity != null ? Timestamp.fromDate(qualificationValidity!) : null,
      'specialty': specialty,
      'areaOfInterest': areaOfInterest,
      // Policy acceptance fields
      'termsOfServiceAcceptedAt': termsOfServiceAcceptedAt != null ? Timestamp.fromDate(termsOfServiceAcceptedAt!) : null,
      'privacyPolicyAcceptedAt': privacyPolicyAcceptedAt != null ? Timestamp.fromDate(privacyPolicyAcceptedAt!) : null,
    };
  }

  // Helper methods for role checking
  bool isNutritionist() {
    return roles.contains(ROLE_NUTRITIONIST);
  }

  bool isPersonalTrainer() {
    return roles.contains(ROLE_PERSONAL_TRAINER);
  }

  bool isPsychologist() {
    return roles.contains(ROLE_PSYCHOLOGIST);
  }

  bool hasRole(String role) {
    return roles.contains(role);
  }

  // Helper method to get professional registration number based on roles
  // Current certification fields first, legacy numero_iscrizione_* as fallback
  String? get professionalRegistrationNumber {
    if (registrationValue != null && registrationValue!.trim().isNotEmpty) {
      return registrationValue;
    }
    if (isNutritionist() || isPsychologist()) {
      return numero_iscrizione_albo;
    } else if (isPersonalTrainer()) {
      return numero_iscrizione_ente;
    }
    return null;
  }

  // Human-readable label for registrationEntityType
  String? get registrationEntityTypeLabel {
    switch (registrationEntityType?.trim().toLowerCase()) {
      case 'universita':
      case 'università':
        return 'Laurea';
      case 'ente':
        return 'Tesserino';
      case 'attestato':
        return 'Attestato';
      default:
        return registrationEntityType;
    }
  }

  // Create a copy with updated fields
  Doctor copyWith({
    String? id,
    String? name,
    String? surname,
    String? sex,
    String? phoneNumber,
    DateTime? birthdate,
    String? address,
    String? cityOfWork,
    String? countryOfWork,
    String? fiscalCode,
    String? email,
    List<String>? roles,
    String? vatNumber,
    double? hourlyFees,
    bool? requiredPasswordChange,
    bool? hasCompletedServiceSetup,
    DateTime? signupApprovalDate,
    String? signupRequestId,
    String? profilePictureUrl,
    // New fields
    bool? isActive,
    bool? isAlive,
    List<String>? languagesSpoken,
    String? numero_iscrizione_albo,
    String? numero_iscrizione_ente,
    String? issuer,
    String? registrationEntityType,
    String? registrationValue,
    DateTime? qualificationValidity,
    String? specialty,
    String? areaOfInterest,
    // Policy acceptance fields
    DateTime? termsOfServiceAcceptedAt,
    DateTime? privacyPolicyAcceptedAt,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      sex: sex ?? this.sex,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthdate: birthdate ?? this.birthdate,
      address: address ?? this.address,
      cityOfWork: cityOfWork ?? this.cityOfWork,
      countryOfWork: countryOfWork ?? this.countryOfWork,
      fiscalCode: fiscalCode ?? this.fiscalCode,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      vatNumber: vatNumber ?? this.vatNumber,
      hourlyFees: hourlyFees ?? this.hourlyFees,
      requiredPasswordChange: requiredPasswordChange ??
          this.requiredPasswordChange,
      hasCompletedServiceSetup:
          hasCompletedServiceSetup ??
              this.hasCompletedServiceSetup,
      signupApprovalDate: signupApprovalDate ??
          this.signupApprovalDate,
      signupRequestId: signupRequestId ?? this.signupRequestId,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      // New fields
      isActive: isActive ?? this.isActive,
      isAlive: isAlive ?? this.isAlive,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      numero_iscrizione_albo: numero_iscrizione_albo ?? this.numero_iscrizione_albo,
      numero_iscrizione_ente: numero_iscrizione_ente ?? this.numero_iscrizione_ente,
      issuer: issuer ?? this.issuer,
      registrationEntityType:
          registrationEntityType ?? this.registrationEntityType,
      registrationValue: registrationValue ?? this.registrationValue,
      qualificationValidity: qualificationValidity ?? this.qualificationValidity,
      specialty: specialty ?? this.specialty,
      areaOfInterest: areaOfInterest ?? this.areaOfInterest,
      // Policy acceptance fields
      termsOfServiceAcceptedAt: termsOfServiceAcceptedAt ?? this.termsOfServiceAcceptedAt,
      privacyPolicyAcceptedAt: privacyPolicyAcceptedAt ?? this.privacyPolicyAcceptedAt,
    );
  }

  // Helper methods to check policy acceptance status
  bool get hasAcceptedTermsOfService => termsOfServiceAcceptedAt != null;
  bool get hasAcceptedPrivacyPolicy => privacyPolicyAcceptedAt != null;
  bool get hasAcceptedAllPolicies => hasAcceptedTermsOfService && hasAcceptedPrivacyPolicy;

  @override
  String toString() {
    return 'Doctor{id: $id, name: $name, surname: $surname, email: $email, roles: $roles}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Doctor &&
        other.id == id &&
        other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}