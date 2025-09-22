class SignupData {
  // NEW: Support for multiple roles instead of single role
  final List<String> roles;
  final String name;
  final String surname;
  final String sex;
  final DateTime? birthdate;
  final String phoneNumber;
  final String cityOfWork;
  final String countryOfWork; // NEW: Added country of work
  final String email;
  final String vatNumber;
  final String fiscalCode;

  // Location and organization fields
  final String address;
  final List<String> languagesSpoken;
  final String organization;
  final String ragioneSociale; // Business name/company name

  // NEW: Professional registration fields (based on role)
  final String? numero_iscrizione_albo; // For nutritionists, psychologists, etc.
  final String? numero_iscrizione_ente; // For personal trainers
  final String issuer; // Professional qualification issuer

  // Optional professional fields
  final String? specialty; // Made optional as in new Doctor model
  final String? areaOfInterest; // Made optional as in new Doctor model
  final DateTime? qualificationValidity; // Professional qualification validity

  SignupData({
    required this.roles, // UPDATED: Now requires list of roles
    required this.name,
    required this.surname,
    required this.sex,
    this.birthdate,
    required this.phoneNumber,
    required this.cityOfWork,
    required this.countryOfWork, // NEW: Required country of work
    required this.email,
    required this.vatNumber,
    required this.fiscalCode,

    // Location and organization fields with defaults
    this.address = '',
    this.languagesSpoken = const [],
    this.organization = '',
    this.ragioneSociale = '',

    // NEW: Professional registration fields
    this.numero_iscrizione_albo,
    this.numero_iscrizione_ente,
    this.issuer = '',

    // Optional professional fields
    this.specialty,
    this.areaOfInterest,
    this.qualificationValidity,
  });

  // LEGACY: Constructor for backward compatibility with single role
  SignupData.fromSingleRole({
    required String role,
    required this.name,
    required this.surname,
    required this.sex,
    this.birthdate,
    required this.phoneNumber,
    required this.cityOfWork,
    this.countryOfWork = 'Italy', // Default country
    required this.email,
    required this.vatNumber,
    required this.fiscalCode,

    // Location and organization fields with defaults
    this.address = '',
    this.languagesSpoken = const [],
    this.organization = '',
    this.ragioneSociale = '',

    // Professional registration fields
    this.numero_iscrizione_albo,
    this.numero_iscrizione_ente,
    this.issuer = '',

    // Optional professional fields
    this.specialty,
    this.areaOfInterest,
    this.qualificationValidity,
  }) : roles = [role]; // Convert single role to list

  // NEW: Helper methods for role checking
  bool hasRole(String role) => roles.contains(role);
  bool get isNutritionist => hasRole('NUTRITIONIST');
  bool get isPersonalTrainer => hasRole('PERSONAL TRAINER');
  bool get isPsychologist => hasRole('PSYCHOLOGIST');

  // LEGACY: For backward compatibility
  String get role => roles.isNotEmpty ? roles.first : '';

  // NEW: Get appropriate registration number based on roles
  String? get professionalRegistrationNumber {
    if (isNutritionist || isPsychologist) {
      return numero_iscrizione_albo;
    } else if (isPersonalTrainer) {
      return numero_iscrizione_ente;
    }
    return null;
  }

  // NEW: Validation methods
  bool get isValid {
    if (roles.isEmpty) return false;
    if (name.isEmpty || surname.isEmpty) return false;
    if (email.isEmpty || fiscalCode.isEmpty) return false;
    if (phoneNumber.isEmpty || cityOfWork.isEmpty) return false;

    // Role-specific validation
    if (isNutritionist || isPsychologist) {
      if (numero_iscrizione_albo == null || numero_iscrizione_albo!.isEmpty) {
        return false;
      }
    }

    if (isPersonalTrainer) {
      if (numero_iscrizione_ente == null || numero_iscrizione_ente!.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // NEW: Get validation errors
  List<String> get validationErrors {
    final errors = <String>[];

    if (roles.isEmpty) errors.add('At least one role must be selected');
    if (name.isEmpty) errors.add('Name is required');
    if (surname.isEmpty) errors.add('Surname is required');
    if (email.isEmpty) errors.add('Email is required');
    if (fiscalCode.isEmpty) errors.add('Fiscal code is required');
    if (phoneNumber.isEmpty) errors.add('Phone number is required');
    if (cityOfWork.isEmpty) errors.add('City of work is required');

    // Role-specific validation
    if (isNutritionist || isPsychologist) {
      if (numero_iscrizione_albo == null || numero_iscrizione_albo!.isEmpty) {
        errors.add('Professional registration number (albo) is required for this role');
      }
    }

    if (isPersonalTrainer) {
      if (numero_iscrizione_ente == null || numero_iscrizione_ente!.isEmpty) {
        errors.add('Professional registration number (ente) is required for personal trainers');
      }
    }

    return errors;
  }

  // Create a copy with updated fields
  SignupData copyWith({
    List<String>? roles,
    String? name,
    String? surname,
    String? sex,
    DateTime? birthdate,
    String? phoneNumber,
    String? cityOfWork,
    String? countryOfWork,
    String? email,
    String? vatNumber,
    String? fiscalCode,

    // Location and organization fields
    String? address,
    List<String>? languagesSpoken,
    String? organization,
    String? ragioneSociale,

    // NEW: Professional registration fields
    String? numero_iscrizione_albo,
    String? numero_iscrizione_ente,
    String? issuer,

    // Optional professional fields
    String? specialty,
    String? areaOfInterest,
    DateTime? qualificationValidity,
  }) {
    return SignupData(
      roles: roles ?? this.roles,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      sex: sex ?? this.sex,
      birthdate: birthdate ?? this.birthdate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cityOfWork: cityOfWork ?? this.cityOfWork,
      countryOfWork: countryOfWork ?? this.countryOfWork,
      email: email ?? this.email,
      vatNumber: vatNumber ?? this.vatNumber,
      fiscalCode: fiscalCode ?? this.fiscalCode,

      // Location and organization fields
      address: address ?? this.address,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      organization: organization ?? this.organization,
      ragioneSociale: ragioneSociale ?? this.ragioneSociale,

      // Professional registration fields
      numero_iscrizione_albo: numero_iscrizione_albo ?? this.numero_iscrizione_albo,
      numero_iscrizione_ente: numero_iscrizione_ente ?? this.numero_iscrizione_ente,
      issuer: issuer ?? this.issuer,

      // Optional professional fields
      specialty: specialty ?? this.specialty,
      areaOfInterest: areaOfInterest ?? this.areaOfInterest,
      qualificationValidity: qualificationValidity ?? this.qualificationValidity,
    );
  }

  // NEW: Add/remove roles methods
  SignupData addRole(String newRole) {
    if (roles.contains(newRole)) return this;
    return copyWith(roles: [...roles, newRole]);
  }

  SignupData removeRole(String roleToRemove) {
    if (!roles.contains(roleToRemove)) return this;
    return copyWith(roles: roles.where((r) => r != roleToRemove).toList());
  }

  SignupData toggleRole(String role) {
    return hasRole(role) ? removeRole(role) : addRole(role);
  }

  // NEW: Convert to Doctor model compatible format
  Map<String, dynamic> toDoctorCreationData() {
    return {
      'roles': roles,
      'name': name,
      'surname': surname,
      'sex': sex,
      'phoneNumber': phoneNumber,
      'birthdate': birthdate,
      'address': address,
      'cityOfWork': cityOfWork,
      'countryOfWork': countryOfWork,
      'fiscalCode': fiscalCode,
      'email': email,
      'vatNumber': vatNumber,
      'languagesSpoken': languagesSpoken,
      'numero_iscrizione_albo': numero_iscrizione_albo,
      'numero_iscrizione_ente': numero_iscrizione_ente,
      'issuer': issuer,
      'specialty': specialty,
      'areaOfInterest': areaOfInterest,
      'qualificationValidity': qualificationValidity,
      'organization': organization,
      'ragioneSociale': ragioneSociale,

      // Set default values for required Doctor fields
      'hourlyFees': 0.0,
      'requiredPasswordChange': true,
      'isActive': true,
      'isAlive': true,
      'profilePictureUrl': '',
    };
  }

  // NEW: Factory constructor from form data
  factory SignupData.fromFormData(Map<String, dynamic> formData) {
    return SignupData(
      roles: formData['roles'] is List
          ? List<String>.from(formData['roles'])
          : [formData['role']?.toString() ?? ''],
      name: formData['name']?.toString() ?? '',
      surname: formData['surname']?.toString() ?? '',
      sex: formData['sex']?.toString() ?? '',
      birthdate: formData['birthdate'] is DateTime
          ? formData['birthdate']
          : null,
      phoneNumber: formData['phoneNumber']?.toString() ?? '',
      cityOfWork: formData['cityOfWork']?.toString() ?? '',
      countryOfWork: formData['countryOfWork']?.toString() ?? 'Italy',
      email: formData['email']?.toString() ?? '',
      vatNumber: formData['vatNumber']?.toString() ?? '',
      fiscalCode: formData['fiscalCode']?.toString() ?? '',
      address: formData['address']?.toString() ?? '',
      languagesSpoken: formData['languagesSpoken'] is List
          ? List<String>.from(formData['languagesSpoken'])
          : [],
      organization: formData['organization']?.toString() ?? '',
      ragioneSociale: formData['ragioneSociale']?.toString() ?? '',
      numero_iscrizione_albo: formData['numero_iscrizione_albo']?.toString(),
      numero_iscrizione_ente: formData['numero_iscrizione_ente']?.toString(),
      issuer: formData['issuer']?.toString() ?? '',
      specialty: formData['specialty']?.toString(),
      areaOfInterest: formData['areaOfInterest']?.toString(),
      qualificationValidity: formData['qualificationValidity'] is DateTime
          ? formData['qualificationValidity']
          : null,
    );
  }

  @override
  String toString() {
    return 'SignupData{roles: $roles, name: $name, surname: $surname, email: $email, cityOfWork: $cityOfWork}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignupData &&
        other.roles.toString() == roles.toString() &&
        other.name == name &&
        other.surname == surname &&
        other.email == email &&
        other.fiscalCode == fiscalCode;
  }

  @override
  int get hashCode {
    return roles.hashCode ^
    name.hashCode ^
    surname.hashCode ^
    email.hashCode ^
    fiscalCode.hashCode;
  }
}