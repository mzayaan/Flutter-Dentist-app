import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bill.dart';

class BillService {
  final _supabase = Supabase.instance.client;

  static const _joinQuery =
      '*, patients(full_name), appointments(appointment_date)';

  Future<List<Bill>> getAllBills() async {
    final response = await _supabase
        .from('bills')
        .select(_joinQuery)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Bill.fromJson(e)).toList();
  }

  Future<List<Bill>> getPatientBills(String patientId) async {
    final response = await _supabase
        .from('bills')
        .select(_joinQuery)
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Bill.fromJson(e)).toList();
  }

  Future<Bill> createBill({
    required String appointmentId,
    required String patientId,
    required double totalAmount,
  }) async {
    final response = await _supabase
        .from('bills')
        .insert({
          'appointment_id': appointmentId,
          'patient_id': patientId,
          'total_amount': totalAmount,
          'status': 'Unpaid',
        })
        .select()
        .single();
    return Bill.fromJson(response);
  }

  Future<void> markAsPaid(String id) async {
    await _supabase.from('bills').update({'status': 'Paid'}).eq('id', id);
  }

  Future<void> markPaidByAppointment(String appointmentId) async {
    await _supabase
        .from('bills')
        .update({'status': 'Paid'})
        .eq('appointment_id', appointmentId);
  }

  Future<double> getTotalRevenue() async {
    final response = await _supabase
        .from('bills')
        .select('total_amount')
        .eq('status', 'Paid');
    double total = 0;
    for (final bill in response as List) {
      total += (bill['total_amount'] as num).toDouble();
    }
    return total;
  }

  Future<int> getPendingBillsCount() async {
    final response =
        await _supabase.from('bills').select('id').eq('status', 'Unpaid');
    return (response as List).length;
  }
}
