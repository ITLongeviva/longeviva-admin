class SignupData {
  final String role;
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
  // New fields
  final String address;
  final List<String> languagesSpoken;
  final String organization;
  final String ragioneSociale; // Business name/company name

  SignupData({
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
    // New fields with defaults
    this.address = '',
    this.languagesSpoken = const [],
    this.organization = '',
    this.ragioneSociale = '',
  });

  // Create a copy with updated fields
  SignupData copyWith({
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
    // New fields
    String? address,
    List<String>? languagesSpoken,
    String? organization,
    String? ragioneSociale,
  }) {
    return SignupData(
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
      // New fields
      address: address ?? this.address,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      organization: organization ?? this.organization,
      ragioneSociale: ragioneSociale ?? this.ragioneSociale,
    );
  }
}