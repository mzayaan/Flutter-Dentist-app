import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin.dart';
import '../models/patient.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<Admin?> loginAdmin(String email, String password) async {
    final response = await _supabase
        .from('admins')
        .select()
        .eq('email', email.trim())
        .eq('password', password)
        .maybeSingle();

    if (response == null) return null;
    return Admin.fromJson(response);
  }

  Future<Patient?> loginPatient(String email, String password) async {
    final response = await _supabase
        .from('patients')
        .select()
        .eq('email', email.trim())
        .eq('password', password)
        .maybeSingle();

    if (response == null) return null;
    return Patient.fromJson(response);
  }

  Future<Patient> registerPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required DateTime dateOfBirth,
  }) async {
    final existing = await _supabase
        .from('patients')
        .select('id')
        .eq('email', email.trim())
        .maybeSingle();

    if (existing != null) {
      throw Exception('An account with this email already exists.');
    }

    final response = await _supabase
        .from('patients')
        .insert({
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
        })
        .select()
        .single();

    return Patient.fromJson(response);
  }

  Future<int> getTotalPatients() async {
    final response = await _supabase.from('patients').select('id');
    return (response as List).length;
  }
}
