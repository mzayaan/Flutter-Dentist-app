import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/appointment.dart';
import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../utils/tab_refresher.dart';
import '../../widgets/status_badge.dart';

String _drName(String? name) {
  final n = name ?? 'Unknown';
  return n.startsWith('Dr.') ? n : 'Dr. $n';
}

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab>
    with AutomaticKeepAliveClientMixin, TabRefresher {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _appointmentService = AppointmentService();
  final _billService = BillService();

  int _totalPatients = 0;
  int _todaysAppointments = 0;
  double _totalRevenue = 0;
  int _pendingBills = 0;
  List<Appointment> _recentAppointments = [];
  bool _loading = true;
  bool _refreshing = false;

  late RealtimeChannel _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void refresh() => _loadData();

  @override
  void initState() {
    super.initState();
    _loadData();
    _channel = _supabase
        .channel('admin_home_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            if (mounted && !_refreshing) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          callback: (payload) {
            if (mounted && !_refreshing) _loadData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    if (!_loading) setState(() => _refreshing = true);
    try {
      final results = await Future.wait([
        _authService.getTotalPatients(),
        _appointmentService.getTodaysAppointments(),
        _billService.getTotalRevenue(),
        _billService.getPendingBillsCount(),
        _appointmentService.getAllAppointments(),
      ]);
      if (!mounted) return;
      setState(() {
        _totalPatients = results[0] as int;
        _todaysAppointments = (results[1] as List).length;
        _totalRevenue = results[2] as double;
        _pendingBills = results[3] as int;
        _recentAppointments =
            (results[4] as List<Appointment>).take(5).toList();
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
        SnackBar(
          content: Text('Error loading dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF1565C0),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, Admin 👋',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s what\'s happening at the clinic today',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.05,
                  children: [
                    _GradientStatCard(
                      title: 'Total Patients',
                      value: '$_totalPatients',
                      icon: Icons.people_alt_rounded,
                      gradient: const [Color(0xFF1565C0), Color(0xFF1976D2)],
                    ),
                    _GradientStatCard(
                      title: "Today's Appointments",
                      value: '$_todaysAppointments',
                      icon: Icons.calendar_today_rounded,
                      gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
                    ),
                    _GradientStatCard(
                      title: 'Total Revenue',
                      value: 'Rs ${_totalRevenue.toStringAsFixed(2)}',
                      icon: Icons.attach_money_rounded,
                      gradient: const [Color(0xFF2E7D32), Color(0xFF43A047)],
                    ),
                    _GradientStatCard(
                      title: 'Pending Bills',
                      value: '$_pendingBills',
                      icon: Icons.receipt_long_rounded,
                      gradient: const [Color(0xFFE65100), Color(0xFFEF6C00)],
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    const Text(
                      'Recent Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Last 5',
                        style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_recentAppointments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        'No appointments yet',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentAppointments.length,
                      separatorBuilder: (_, index) =>
                          Divider(height: 1, color: Colors.grey[100]),
                      itemBuilder: (context, index) {
                        final a = _recentAppointments[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.patientName ?? 'Unknown Patient',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _drName(a.dentistName),
                                      style: const TextStyle(
                                          color: Color(0xFF1565C0),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('EEE, dd MMM yyyy')
                                          .format(a.appointmentDate),
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(status: a.status),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_refreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Color(0xFF1565C0),
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _GradientStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _GradientStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
