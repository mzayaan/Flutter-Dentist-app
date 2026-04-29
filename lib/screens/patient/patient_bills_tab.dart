import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bill.dart';
import '../../models/patient.dart';
import '../../services/bill_service.dart';
import '../../widgets/status_badge.dart';

class PatientBillsTab extends StatefulWidget {
  final Patient patient;

  const PatientBillsTab({super.key, required this.patient});

  @override
  State<PatientBillsTab> createState() => _PatientBillsTabState();
}

class _PatientBillsTabState extends State<PatientBillsTab> {
  final _billService = BillService();
  List<Bill> _bills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _loading = true);
    try {
      final list =
          await _billService.getPatientBills(widget.patient.id);
      if (!mounted) return;
      setState(() {
        _bills = list;
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

  double get _totalOwed => _bills
      .where((b) => b.status == 'Unpaid')
      .fold(0.0, (sum, b) => sum + b.totalAmount);

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1565C0)))
        : RefreshIndicator(
            onRefresh: _loadBills,
            color: const Color(0xFF1565C0),
            child: _bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No bills yet',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 15)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_totalOwed > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Outstanding Balance',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange),
                                    ),
                                    Text(
                                      '\$${_totalOwed.toStringAsFixed(2)} unpaid',
                                      style: TextStyle(
                                          color: Colors.orange[800],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._bills.map((b) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            shadowColor: Colors.black12,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: b.status == 'Paid'
                                          ? Colors.green.withValues(alpha:0.12)
                                          : Colors.orange.withValues(alpha:0.12),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      b.status == 'Paid'
                                          ? Icons.check_circle_rounded
                                          : Icons.receipt_long_rounded,
                                      color: b.status == 'Paid'
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (b.appointmentDate != null)
                                          Text(
                                            'Appointment: ${DateFormat('dd MMM yyyy').format(DateTime.parse(b.appointmentDate!))}',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12),
                                          ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${b.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                        if (b.createdAt != null)
                                          Text(
                                            'Issued: ${DateFormat('dd MMM yyyy').format(b.createdAt!)}',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(status: b.status),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
          );
  }
}
