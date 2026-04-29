import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/appointment_service.dart';
import '../../widgets/status_badge.dart';

class PatientHomeTab extends StatefulWidget {
  final Patient patient;

  const PatientHomeTab({super.key, required this.patient});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab> {
  final _appointmentService = AppointmentService();
  List<Appointment> _upcoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final all = await _appointmentService
          .getPatientAppointments(widget.patient.id);
      final now = DateTime.now();
      final upcoming = all
          .where((a) =>
              !a.appointmentDate.isBefore(
                  DateTime(now.year, now.month, now.day)) &&
              a.status != 'Cancelled')
          .toList();
      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF1565C0),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha:0.25),
                        radius: 24,
                        child: Text(
                          widget.patient.fullName.isNotEmpty
                              ? widget.patient.fullName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha:0.85),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              widget.patient.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.medical_services_rounded,
                          color: Colors.white54, size: 32),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_upcoming.length} upcoming appointment${_upcoming.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator(
                  color: Color(0xFF1565C0)))
            else if (_upcoming.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No upcoming appointments',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Book an appointment to get started',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...(_upcoming.map((a) => _AppointmentCard(appointment: a))),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.treatmentName ?? 'Treatment',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                StatusBadge(status: appointment.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF1565C0)),
                const SizedBox(width: 4),
                Text(
                  'Dr. ${appointment.dentistName ?? "Unknown"}',
                  style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('EEE, dd MMM yyyy')
                      .format(appointment.appointmentDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time_outlined,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  appointment.appointmentTime,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
