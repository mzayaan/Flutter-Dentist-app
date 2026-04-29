class Dentist {
  final String id;
  final String name;
  final String specialization;
  final String email;
  final String phone;
  final String availableDays;
  final DateTime? createdAt;

  Dentist({
    required this.id,
    required this.name,
    required this.specialization,
    required this.email,
    required this.phone,
    required this.availableDays,
    this.createdAt,
  });

  factory Dentist.fromJson(Map<String, dynamic> json) {
    return Dentist(
      id: json['id'] as String,
      name: json['name'] as String,
      specialization: json['specialization'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      availableDays: json['available_days'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'specialization': specialization,
        'email': email,
        'phone': phone,
        'available_days': availableDays,
      };
}
