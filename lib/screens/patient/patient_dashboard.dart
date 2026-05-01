import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../screens/auth/splash_screen.dart';
import '../../utils/tab_refresher.dart';
import 'patient_home_tab.dart';
import 'patient_book_tab.dart';
import 'patient_appointments_tab.dart';
import 'patient_bills_tab.dart';
import 'patient_profile_tab.dart';

class PatientDashboard extends StatefulWidget {
  final Patient patient;

  const PatientDashboard({super.key, required this.patient});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;

  late final List<GlobalKey> _pageKeys;
  late final List<Widget> _tabs;

  final List<String> _titles = const [
    'SmileCare',
    'Book Appointment',
    'My Appointments',
    'My Bills',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _pageKeys = List.generate(5, (_) => GlobalKey());
    _tabs = [
      PatientHomeTab(key: _pageKeys[0], patient: widget.patient),
      PatientBookTab(
        key: _pageKeys[1],
        patient: widget.patient,
        onBookingComplete: _onBookingComplete,
      ),
      PatientAppointmentsTab(key: _pageKeys[2], patient: widget.patient),
      PatientBillsTab(key: _pageKeys[3], patient: widget.patient),
      PatientProfileTab(key: _pageKeys[4], patient: widget.patient),
    ];
  }

  void _onBookingComplete() {
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _pageKeys[0].currentState;
      if (state is TabRefresher) (state as TabRefresher).refresh();
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          final state = _pageKeys[index].currentState;
          if (state is TabRefresher) (state as TabRefresher).refresh();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle_rounded),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
