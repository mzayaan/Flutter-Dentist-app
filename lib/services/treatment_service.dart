import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treatment.dart';

class TreatmentService {
  final _supabase = Supabase.instance.client;

  Future<List<Treatment>> getAllTreatments() async {
    final response =
        await _supabase.from('treatments').select().order('name');
    return (response as List).map((e) => Treatment.fromJson(e)).toList();
  }

  Future<Treatment> addTreatment({
    required String name,
    required String description,
    required double price,
    required int durationMins,
  }) async {
    final response = await _supabase
        .from('treatments')
        .insert({
          'name': name.trim(),
          'description': description.trim(),
          'price': price,
          'duration_mins': durationMins,
        })
        .select()
        .single();
    return Treatment.fromJson(response);
  }

  Future<Treatment> updateTreatment({
    required String id,
    required String name,
    required String description,
    required double price,
    required int durationMins,
  }) async {
    final response = await _supabase
        .from('treatments')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'price': price,
          'duration_mins': durationMins,
        })
        .eq('id', id)
        .select()
        .single();
    return Treatment.fromJson(response);
  }

  Future<void> deleteTreatment(String id) async {
    await _supabase.from('treatments').delete().eq('id', id);
  }
}
