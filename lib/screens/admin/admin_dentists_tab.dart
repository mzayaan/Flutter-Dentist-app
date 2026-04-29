import 'package:flutter/material.dart';
import '../../models/dentist.dart';
import '../../services/dentist_service.dart';

class AdminDentistsTab extends StatefulWidget {
  const AdminDentistsTab({super.key});

  @override
  State<AdminDentistsTab> createState() => _AdminDentistsTabState();
}

class _AdminDentistsTabState extends State<AdminDentistsTab> {
  final _dentistService = DentistService();
  List<Dentist> _dentists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDentists();
  }

  Future<void> _loadDentists() async {
    setState(() => _loading = true);
    try {
      final list = await _dentistService.getAllDentists();
      if (!mounted) return;
      setState(() {
        _dentists = list;
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

  Future<void> _showDentistDialog({Dentist? dentist}) async {
    final nameCtrl = TextEditingController(text: dentist?.name ?? '');
    final specCtrl =
        TextEditingController(text: dentist?.specialization ?? '');
    final emailCtrl = TextEditingController(text: dentist?.email ?? '');
    final phoneCtrl = TextEditingController(text: dentist?.phone ?? '');
    final daysCtrl =
        TextEditingController(text: dentist?.availableDays ?? '');
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
            dentist == null ? 'Add Dentist' : 'Edit Dentist',
            style: const TextStyle(
                color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(nameCtrl, 'Name', Icons.person_outline),
                  const SizedBox(height: 12),
                  _dialogField(specCtrl, 'Specialization',
                      Icons.medical_services_outlined),
                  const SizedBox(height: 12),
                  _dialogField(
                      emailCtrl, 'Email', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _dialogField(phoneCtrl, 'Phone', Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _dialogField(
                      daysCtrl, 'Available Days', Icons.calendar_today_outlined,
                      hint: 'e.g. Mon, Tue, Wed'),
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
                        if (dentist == null) {
                          await _dentistService.addDentist(
                            name: nameCtrl.text,
                            specialization: specCtrl.text,
                            email: emailCtrl.text,
                            phone: phoneCtrl.text,
                            availableDays: daysCtrl.text,
                          );
                        } else {
                          await _dentistService.updateDentist(
                            id: dentist.id,
                            name: nameCtrl.text,
                            specialization: specCtrl.text,
                            email: emailCtrl.text,
                            phone: phoneCtrl.text,
                            availableDays: daysCtrl.text,
                          );
                        }
                        if (!mounted) return;
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadDentists();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(dentist == null
                                ? 'Dentist added successfully!'
                                : 'Dentist updated successfully!'),
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
                  : Text(dentist == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDentist(Dentist dentist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dentist'),
        content: Text(
            'Are you sure you want to delete Dr. ${dentist.name}?'),
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
      await _dentistService.deleteDentist(dentist.id);
      _loadDentists();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dentist deleted successfully.'),
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
          : _dentists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_rounded,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No dentists found',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDentists,
                  color: const Color(0xFF1565C0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dentists.length,
                    itemBuilder: (context, index) {
                      final d = _dentists[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: Colors.black12,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF1565C0).withValues(alpha: 0.12),
                            radius: 24,
                            child: Text(
                              d.name.isNotEmpty ? d.name[0].toUpperCase() : 'D',
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Text(
                            'Dr. ${d.name}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(d.specialization,
                                  style: const TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.w500)),
                              Text(d.phone,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                              Text(d.availableDays,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: Color(0xFF1565C0)),
                                onPressed: () =>
                                    _showDentistDialog(dentist: d),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded,
                                    color: Colors.red),
                                onPressed: () => _deleteDentist(d),
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
        onPressed: () => _showDentistDialog(),
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
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      validator: (v) =>
          v == null || v.isEmpty ? 'This field is required' : null,
    );
  }
}
