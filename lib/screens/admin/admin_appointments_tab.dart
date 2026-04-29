import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../widgets/status_badge.dart';

class AdminAppointmentsTab extends StatefulWidget {
  const AdminAppointmentsTab({super.key});

  @override
  State<AdminAppointmentsTab> createState() => _AdminAppointmentsTabState();
}

class _AdminAppointmentsTabState extends State<AdminAppointmentsTab> {
  final _appointmentService = AppointmentService();
  final _billService = BillService();
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _loading = true);
    try {
      final list = await _appointmentService.getAllAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeStatus(Appointment appt) async {
    final options = ['Confirmed', 'Cancelled', 'Completed']
        .where((s) => s != appt.status)
        .toList();

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Status',
            style: TextStyle(
                color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((opt) => ListTile(
                    leading: StatusBadge(status: opt),
                    onTap: () => Navigator.pop(ctx, opt),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;
    try {
      await _appointmentService.updateStatus(appt.id, selected);
      if (selected == 'Completed') {
        await _billService.markPaidByAppointment(appt.id);
      }
      _loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to $selected.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No appointments yet',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppointments,
                  color: const Color(0xFF1565C0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final a = _appointments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: Colors.black12,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.patientName ?? 'Unknown Patient',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                  StatusBadge(status: a.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _infoRow(Icons.person_outline,
                                  'Dr. ${a.dentistName ?? "Unknown"}',
                                  const Color(0xFF1565C0)),
                              _infoRow(
                                  Icons.medical_services_outlined,
                                  a.treatmentName ?? 'Unknown Treatment',
                                  Colors.teal),
                              _infoRow(
                                  Icons.calendar_today_outlined,
                                  DateFormat('EEE, dd MMM yyyy')
                                      .format(a.appointmentDate),
                                  Colors.grey[700]!),
                              _infoRow(Icons.access_time_outlined,
                                  a.appointmentTime, Colors.grey[700]!),
                              if (a.notes != null && a.notes!.isNotEmpty)
                                _infoRow(Icons.notes_outlined, a.notes!,
                                    Colors.grey[600]!),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _changeStatus(a),
                                  icon: const Icon(Icons.edit_rounded,
                                      size: 16),
                                  label: const Text('Change Status'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
