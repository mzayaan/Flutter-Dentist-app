import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dentist.dart';

class DentistService {
  final _supabase = Supabase.instance.client;

  Future<List<Dentist>> getAllDentists() async {
    final response =
        await _supabase.from('dentists').select().order('name');
    return (response as List).map((e) => Dentist.fromJson(e)).toList();
  }

  Future<Dentist> addDentist({
    required String name,
    required String specialization,
    required String email,
    required String phone,
    required String availableDays,
  }) async {
    final response = await _supabase
        .from('dentists')
        .insert({
          'name': name.trim(),
          'specialization': specialization.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'available_days': availableDays.trim(),
        })
        .select()
        .single();
    return Dentist.fromJson(response);
  }

  Future<Dentist> updateDentist({
    required String id,
    required String name,
    required String specialization,
    required String email,
    required String phone,
    required String availableDays,
  }) async {
    final response = await _supabase
        .from('dentists')
        .update({
          'name': name.trim(),
          'specialization': specialization.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'available_days': availableDays.trim(),
        })
        .eq('id', id)
        .select()
        .single();
    return Dentist.fromJson(response);
  }

  Future<void> deleteDentist(String id) async {
    await _supabase.from('dentists').delete().eq('id', id);
  }
}
