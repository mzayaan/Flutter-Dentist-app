import 'package:flutter/material.dart';
import '../../models/treatment.dart';
import '../../services/treatment_service.dart';

class AdminTreatmentsTab extends StatefulWidget {
  const AdminTreatmentsTab({super.key});

  @override
  State<AdminTreatmentsTab> createState() => _AdminTreatmentsTabState();
}

class _AdminTreatmentsTabState extends State<AdminTreatmentsTab> {
  final _treatmentService = TreatmentService();
  List<Treatment> _treatments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }

  Future<void> _loadTreatments() async {
    setState(() => _loading = true);
    try {
      final list = await _treatmentService.getAllTreatments();
      if (!mounted) return;
      setState(() {
        _treatments = list;
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

  Future<void> _showTreatmentDialog({Treatment? treatment}) async {
    final nameCtrl =
        TextEditingController(text: treatment?.name ?? '');
    final descCtrl =
        TextEditingController(text: treatment?.description ?? '');
    final priceCtrl = TextEditingController(
        text: treatment != null ? treatment.price.toString() : '');
    final durationCtrl = TextEditingController(
        text: treatment != null ? treatment.durationMins.toString() : '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            treatment == null ? 'Add Treatment' : 'Edit Treatment',
            style: const TextStyle(
                color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                      nameCtrl, 'Treatment Name', Icons.medical_services_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_outlined,
                          color: Color(0xFF1565C0), size: 20),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    priceCtrl,
                    'Price (\$)',
                    Icons.attach_money_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter price';
                      if (double.tryParse(v) == null) {
                        return 'Enter valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    durationCtrl,
                    'Duration (mins)',
                    Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter duration';
                      if (int.tryParse(v) == null) {
                        return 'Enter whole number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        if (treatment == null) {
                          await _treatmentService.addTreatment(
                            name: nameCtrl.text,
                            description: descCtrl.text,
                            price: double.parse(priceCtrl.text),
                            durationMins: int.parse(durationCtrl.text),
                          );
                        } else {
                          await _treatmentService.updateTreatment(
                            id: treatment.id,
                            name: nameCtrl.text,
                            description: descCtrl.text,
                            price: double.parse(priceCtrl.text),
                            durationMins: int.parse(durationCtrl.text),
                          );
                        }
                        if (!mounted) return;
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadTreatments();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(treatment == null
                                ? 'Treatment added successfully!'
                                : 'Treatment updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(treatment == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTreatment(Treatment treatment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Treatment'),
        content:
            Text('Are you sure you want to delete "${treatment.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _treatmentService.deleteTreatment(treatment.id);
      _loadTreatments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Treatment deleted successfully.'),
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
          : _treatments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No treatments found',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTreatments,
                  color: const Color(0xFF1565C0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _treatments.length,
                    itemBuilder: (context, index) {
                      final t = _treatments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: Colors.black12,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medical_services_rounded,
                                color: Colors.teal, size: 24),
                          ),
                          title: Text(
                            t.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                t.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '\$${t.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${t.durationMins} mins',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: Color(0xFF1565C0)),
                                onPressed: () =>
                                    _showTreatmentDialog(treatment: t),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded,
                                    color: Colors.red),
                                onPressed: () => _deleteTreatment(t),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTreatmentDialog(),
        backgroundColor: const Color(0xFF1565C0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator ??
          (v) => v == null || v.isEmpty ? 'This field is required' : null,
    );
  }
}
