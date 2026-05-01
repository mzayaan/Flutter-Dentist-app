import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/appointment.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../utils/tab_refresher.dart';
import '../../widgets/status_badge.dart';

String _drName(String? name) {
  final n = name ?? 'Unknown';
  return n.startsWith('Dr.') ? n : 'Dr. $n';
}

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AdminAppointmentsTab extends StatefulWidget {
  const AdminAppointmentsTab({super.key});

  @override
  State<AdminAppointmentsTab> createState() => _AdminAppointmentsTabState();
}

class _AdminAppointmentsTabState extends State<AdminAppointmentsTab>
    with AutomaticKeepAliveClientMixin, TabRefresher {
  final _supabase = Supabase.instance.client;
  final _appointmentService = AppointmentService();
  final _billService = BillService();
  List<Appointment> _appointments = [];
  bool _loading = true;
  bool _refreshing = false;

  // Filter: null = all dentists
  String? _dentistFilterId;

  late RealtimeChannel _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void refresh() => _loadAppointments();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _channel = _supabase
        .channel('admin_appointments_rt')
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
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    if (!_loading) setState(() => _refreshing = true);
    try {
      final list = await _appointmentService.getAllAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _loading = false;
        _refreshing = false;
        // Reset filter if selected dentist no longer in list
        if (_dentistFilterId != null &&
            !list.any((a) => a.dentistId == _dentistFilterId)) {
          _dentistFilterId = null;
        }
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

  // Unique (dentistId, dentistName) pairs extracted from loaded appointments
  List<MapEntry<String, String>> get _dentistOptions {
    final seen = <String>{};
    final result = <MapEntry<String, String>>[];
    for (final a in _appointments) {
      if (!seen.contains(a.dentistId) && a.dentistName != null) {
        seen.add(a.dentistId);
        result.add(MapEntry(a.dentistId, _drName(a.dentistName)));
      }
    }
    result.sort((a, b) => a.value.compareTo(b.value));
    return result;
  }

  // Build a flat list where DateTime entries are date-group headers
  // and Appointment entries are the cards. Sorted ascending for timeline view.
  List<dynamic> get _displayItems {
    List<Appointment> filtered = _dentistFilterId == null
        ? List.of(_appointments)
        : _appointments
            .where((a) => a.dentistId == _dentistFilterId)
            .toList();

    filtered.sort((a, b) {
      final dc = a.appointmentDate.compareTo(b.appointmentDate);
      return dc != 0 ? dc : a.appointmentTime.compareTo(b.appointmentTime);
    });

    final items = <dynamic>[];
    DateTime? lastDate;
    for (final appt in filtered) {
      if (lastDate == null || !_isSameDay(appt.appointmentDate, lastDate)) {
        items.add(appt.appointmentDate);
        lastDate = appt.appointmentDate;
      }
      items.add(appt);
    }
    return items;
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
      } else if (selected == 'Cancelled') {
        await _billService.deleteByAppointment(appt.id);
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
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          if (_refreshing)
            const LinearProgressIndicator(
              color: Color(0xFF1565C0),
              backgroundColor: Colors.transparent,
            ),

          // Dentist filter bar
          if (!_loading && _appointments.isNotEmpty)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 18, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _dentistFilterId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('All Dentists',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF1565C0))),
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Dentists',
                                style: TextStyle(
                                    color: Color(0xFF1565C0))),
                          ),
                          ..._dentistOptions.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value,
                                    style: const TextStyle(
                                        color: Color(0xFF1565C0))),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _dentistFilterId = v),
                      ),
                    ),
                  ),
                  if (_dentistFilterId != null)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _dentistFilterId = null),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          if (!_loading && _appointments.isNotEmpty)
            Divider(height: 1, color: Colors.grey[200]),

          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF1565C0)))
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
                        child: Builder(builder: (context) {
                          final items = _displayItems;
                          if (items.isEmpty) {
                            return ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.person_search_outlined,
                                          size: 56,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No appointments for this dentist',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 12,
                                bottom: 16),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is DateTime) {
                                return _DateHeader(date: item);
                              }
                              return _AppointmentCard(
                                appointment: item as Appointment,
                                onChangeStatus: _changeStatus,
                              );
                            },
                          );
                        }),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final today = _isToday(date);
    final tomorrow = _isSameDay(
        date, DateTime.now().add(const Duration(days: 1)));
    String label;
    if (today) {
      label = 'Today · ${DateFormat('EEE, dd MMM yyyy').format(date)}';
    } else if (tomorrow) {
      label = 'Tomorrow · ${DateFormat('EEE, dd MMM yyyy').format(date)}';
    } else {
      label = DateFormat('EEEE, dd MMM yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: today
                  ? const Color(0xFF1565C0)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: today ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey[300], height: 1)),
        ],
      ),
    );
  }
}

// ─── Appointment card ─────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Future<void> Function(Appointment) onChangeStatus;

  const _AppointmentCard({
    required this.appointment,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                    a.patientName ?? 'Unknown Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                StatusBadge(status: a.status),
              ],
            ),
            const SizedBox(height: 8),
            // Time displayed prominently
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: Color(0xFF1565C0)),
                  const SizedBox(width: 5),
                  Text(
                    a.appointmentTime,
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.person_outline, _drName(a.dentistName),
                const Color(0xFF1565C0)),
            _infoRow(
                Icons.medical_services_outlined,
                a.treatmentName ?? 'Unknown Treatment',
                Colors.teal),
            if (a.notes != null && a.notes!.isNotEmpty)
              _infoRow(Icons.notes_outlined, a.notes!, Colors.grey[600]!),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onChangeStatus(a),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Change Status'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
