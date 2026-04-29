class Patient {
  final String id;
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;

  Patient({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    this.dateOfBirth,
    this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
