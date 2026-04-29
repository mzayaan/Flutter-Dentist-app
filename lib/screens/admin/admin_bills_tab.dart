import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bill.dart';
import '../../services/bill_service.dart';
import '../../widgets/status_badge.dart';

class AdminBillsTab extends StatefulWidget {
  const AdminBillsTab({super.key});

  @override
  State<AdminBillsTab> createState() => _AdminBillsTabState();
}

class _AdminBillsTabState extends State<AdminBillsTab> {
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
      final list = await _billService.getAllBills();
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

  Future<void> _markAsPaid(Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text(
          'Mark bill of \$${bill.totalAmount.toStringAsFixed(2)} for '
          '${bill.patientName ?? "patient"} as paid?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _billService.markAsPaid(bill.id);
      _loadBills();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill marked as paid successfully.'),
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
          : _bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No bills found',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBills,
                  color: const Color(0xFF1565C0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final b = _bills[index];
                      return Card(
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
                                  borderRadius: BorderRadius.circular(12),
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
                                    Text(
                                      b.patientName ?? 'Unknown Patient',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    if (b.appointmentDate != null)
                                      Text(
                                        'Appt: ${DateFormat('dd MMM yyyy').format(DateTime.parse(b.appointmentDate!))}',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${b.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(status: b.status),
                                  if (b.status == 'Unpaid') ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 30,
                                      child: ElevatedButton(
                                        onPressed: () => _markAsPaid(b),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          textStyle:
                                              const TextStyle(fontSize: 11),
                                        ),
                                        child: const Text('Mark Paid'),
                                      ),
                                    ),
                                  ],
                                ],
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
}
