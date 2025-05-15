class Admin {
  static const String ROLE_ADMIN = "ADMIN";

  final String id;
  final String email;
  final String name;
  final String password;

  Admin({
    required this.id,
    required this.email,
    required this.name,
    required this.password,
  });

  // Factory constructor to create an Admin object from a JSON map
  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      password: json['password'] ?? '',
    );
  }

  // Method to convert an Admin object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'password': password,
    };
  }
}