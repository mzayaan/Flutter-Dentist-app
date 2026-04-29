import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment.dart';

class AppointmentService {
  final _supabase = Supabase.instance.client;

  static const _joinQuery =
      '*, patients(full_name), dentists(name), treatments(name, price)';

  Future<List<Appointment>> getAllAppointments() async {
    final response = await _supabase
        .from('appointments')
        .select(_joinQuery)
        .order('appointment_date', ascending: false);
    return (response as List).map((e) => Appointment.fromJson(e)).toList();
  }

  Future<List<Appointment>> getPatientAppointments(String patientId) async {
    final response = await _supabase
        .from('appointments')
        .select(_joinQuery)
        .eq('patient_id', patientId)
        .order('appointment_date', ascending: false);
    return (response as List).map((e) => Appointment.fromJson(e)).toList();
  }

  Future<List<Appointment>> getTodaysAppointments() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await _supabase
        .from('appointments')
        .select(_joinQuery)
        .eq('appointment_date', today);
    return (response as List).map((e) => Appointment.fromJson(e)).toList();
  }

  Future<bool> hasPendingOnDate(String patientId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await _supabase
        .from('appointments')
        .select('id')
        .eq('patient_id', patientId)
        .eq('appointment_date', dateStr)
        .eq('status', 'Pending')
        .maybeSingle();
    return response != null;
  }

  Future<Appointment> bookAppointment({
    required String patientId,
    required String dentistId,
    required String treatmentId,
    required DateTime appointmentDate,
    required String appointmentTime,
    String? notes,
  }) async {
    final response = await _supabase
        .from('appointments')
        .insert({
          'patient_id': patientId,
          'dentist_id': dentistId,
          'treatment_id': treatmentId,
          'appointment_date': appointmentDate.toIso8601String().split('T')[0],
          'appointment_time': appointmentTime,
          'status': 'Pending',
          'notes': notes,
        })
        .select()
        .single();
    return Appointment.fromJson(response);
  }

  Future<void> updateStatus(String id, String status) async {
    await _supabase
        .from('appointments')
        .update({'status': status})
        .eq('id', id);
  }
}
