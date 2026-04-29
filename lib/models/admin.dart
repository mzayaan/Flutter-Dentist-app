class Admin {
  final String id;
  final String email;
  final String password;

  Admin({required this.id, required this.email, required this.password});

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }
}
