import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../utils/tab_refresher.dart';
import '../../widgets/status_badge.dart';

String _drName(String? name) {
  final n = name ?? 'Unknown';
  return n.startsWith('Dr.') ? n : 'Dr. $n';
}

class PatientAppointmentsTab extends StatefulWidget {
  final Patient patient;

  const PatientAppointmentsTab({super.key, required this.patient});

  @override
  State<PatientAppointmentsTab> createState() =>
      _PatientAppointmentsTabState();
}

class _PatientAppointmentsTabState extends State<PatientAppointmentsTab>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        TabRefresher {
  final _supabase = Supabase.instance.client;
  final _appointmentService = AppointmentService();
  final _billService = BillService();
  List<Appointment> _upcoming = [];
  List<Appointment> _past = [];
  bool _loading = true;
  bool _refreshing = false;
  late TabController _tabController;
  late RealtimeChannel _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void refresh() => _loadAppointments();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
    _channel = _supabase
        .channel('patient_appts_rt_${widget.patient.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            if (mounted && !_refreshing) _loadAppointments();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    if (!_loading) setState(() => _refreshing = true);
    try {
      final all =
          await _appointmentService.getPatientAppointments(widget.patient.id);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!mounted) return;
      setState(() {
        _upcoming = all
            .where((a) =>
                !a.appointmentDate.isBefore(today) && a.status != 'Cancelled')
            .toList();
        _past = all
            .where((a) =>
                a.appointmentDate.isBefore(today) ||
                a.status == 'Cancelled' ||
                a.status == 'Completed')
            .toList();
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelAppointment(Appointment appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
          'Cancel appointment on ${DateFormat('dd MMM yyyy').format(appt.appointmentDate)}?\n\n'
          'The associated bill will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _appointmentService.updateStatus(appt.id, 'Cancelled');
      await _billService.deleteByAppointment(appt.id);
      _loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled and bill removed.'),
          backgroundColor: Colors.orange,
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
    super.build(context);
    return Column(
      children: [
        if (_refreshing)
          const LinearProgressIndicator(
            color: Color(0xFF1565C0),
            backgroundColor: Colors.transparent,
          ),
        Container(
          color: const Color(0xFF1565C0),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Upcoming (${_upcoming.length})'),
              Tab(text: 'Past (${_past.length})'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_upcoming, canCancel: true),
                    _buildList(_past, canCancel: false),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildList(List<Appointment> list, {required bool canCancel}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No appointments',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      color: const Color(0xFF1565C0),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final a = list[index];
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
                          a.treatmentName ?? 'Treatment',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      StatusBadge(status: a.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: Color(0xFF1565C0)),
                    const SizedBox(width: 4),
                    Text(_drName(a.dentistName),
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, dd MMM yyyy').format(a.appointmentDate),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_outlined,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(a.appointmentTime,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ]),
                  if (a.treatmentPrice != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.currency_rupee_rounded,
                          size: 14, color: Colors.grey[600]),
                      Text(
                        'Rs ${a.treatmentPrice!.toStringAsFixed(2)}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ]),
                  ],
                  if (a.notes != null && a.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(a.notes!,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  if (canCancel && a.status == 'Pending') ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _cancelAppointment(a),
                        icon: const Icon(Icons.cancel_outlined,
                            size: 16, color: Colors.red),
                        label: const Text('Cancel',
                            style: TextStyle(color: Colors.red)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
