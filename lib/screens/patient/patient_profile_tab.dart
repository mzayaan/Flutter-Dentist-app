import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/patient.dart';

class PatientProfileTab extends StatefulWidget {
  final Patient patient;

  const PatientProfileTab({super.key, required this.patient});

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final patient = widget.patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
            child: Text(
              patient.fullName.isNotEmpty
                  ? patient.fullName[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            patient.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Patient',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 28),
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
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: patient.fullName,
                ),
                _divider(),
                _ProfileTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: patient.email,
                ),
                _divider(),
                _ProfileTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: patient.phone,
                ),
                _divider(),
                _ProfileTile(
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: patient.dateOfBirth != null
                      ? DateFormat('dd MMMM yyyy')
                          .format(patient.dateOfBirth!)
                      : 'Not provided',
                ),
                if (patient.createdAt != null) ...[
                  _divider(),
                  _ProfileTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Member Since',
                    value: DateFormat('MMMM yyyy')
                        .format(patient.createdAt!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services_rounded,
                    color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmileCare Patient',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        'Thank you for trusting us with your dental health.',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: Colors.grey[100],
        indent: 56,
      );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
