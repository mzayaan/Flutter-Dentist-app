import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/dentist.dart';
import '../../models/treatment.dart';
import '../../services/dentist_service.dart';
import '../../services/treatment_service.dart';
import '../../utils/tab_refresher.dart';

String _formatDrName(String name) {
  return name.startsWith('Dr.') ? name : 'Dr. $name';
}

class AdminDentistsTab extends StatefulWidget {
  const AdminDentistsTab({super.key});

  @override
  State<AdminDentistsTab> createState() => _AdminDentistsTabState();
}

class _AdminDentistsTabState extends State<AdminDentistsTab>
    with AutomaticKeepAliveClientMixin, TabRefresher {
  final _supabase = Supabase.instance.client;
  final _dentistService = DentistService();
  final _treatmentService = TreatmentService();

  List<Dentist> _dentists = [];
  List<Treatment> _allTreatments = [];
  Map<String, List<String>> _dentistTreatmentsMap = {};
  bool _loading = true;
  bool _refreshing = false;

  late RealtimeChannel _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void refresh() => _loadDentists();

  @override
  void initState() {
    super.initState();
    _loadDentists();
    _channel = _supabase
        .channel('admin_dentists_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dentists',
          callback: (payload) {
            if (mounted && !_refreshing) _loadDentists();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dentist_treatments',
          callback: (payload) {
            if (mounted && !_refreshing) _loadDentists();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadDentists() async {
    if (!mounted) return;
    if (!_loading) setState(() => _refreshing = true);
    try {
      final dentistsFuture = _dentistService.getAllDentists();
      final treatmentsFuture = _treatmentService.getAllTreatments();
      final dtFuture = _supabase
          .from('dentist_treatments')
          .select('dentist_id, treatments(name)');

      final dentists = await dentistsFuture;
      final treatments = await treatmentsFuture;
      final dtRows = await dtFuture as List;

      if (!mounted) return;

      final Map<String, List<String>> dtMap = {};
      for (final row in dtRows) {
        final dentistId = row['dentist_id'] as String;
        final tData = row['treatments'];
        if (tData != null) {
          final name = (tData as Map<String, dynamic>)['name'] as String;
          dtMap.putIfAbsent(dentistId, () => []).add(name);
        }
      }

      setState(() {
        _dentists = dentists;
        _allTreatments = treatments;
        _dentistTreatmentsMap = dtMap;
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

  Future<void> _showDentistDialog({Dentist? dentist}) async {
    // Pre-load existing treatment assignments for edit
    Set<String> selectedTreatmentIds = {};
    if (dentist != null) {
      try {
        selectedTreatmentIds =
            await _dentistService.getDentistTreatmentIds(dentist.id);
        if (!mounted) return;
      } catch (_) {}
    }

    final nameCtrl = TextEditingController(text: dentist?.name ?? '');
    final specCtrl =
        TextEditingController(text: dentist?.specialization ?? '');
    final emailCtrl = TextEditingController(text: dentist?.email ?? '');
    final phoneCtrl = TextEditingController(text: dentist?.phone ?? '');
    final daysCtrl =
        TextEditingController(text: dentist?.availableDays ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    if (!mounted) return;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField(nameCtrl, 'Name', Icons.person_outline),
                  const SizedBox(height: 12),
                  _dialogField(specCtrl, 'Specialization',
                      Icons.medical_services_outlined),
                  const SizedBox(height: 12),
                  _dialogField(emailCtrl, 'Email', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      hintText: '+230 5XXX XXXX',
                      prefixIcon: const Icon(Icons.phone_outlined,
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter phone number';
                      }
                      final t = v.trim();
                      if (t.startsWith('+230')) return null;
                      if (t.length == 8 && int.tryParse(t) != null) {
                        return null;
                      }
                      return 'Use +230 XXXX XXXX or 8-digit number';
                    },
                  ),
                  const SizedBox(height: 12),
                  _dialogField(daysCtrl, 'Available Days',
                      Icons.calendar_today_outlined,
                      hint: 'e.g. Mon, Tue, Wed'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Assigned Treatments',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(height: 4),
                  if (_allTreatments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No treatments available. Add treatments first.',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: _allTreatments.map((t) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.name,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              'Rs ${t.price.toStringAsFixed(0)} · ${t.durationMins} mins',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                            value: selectedTreatmentIds.contains(t.id),
                            activeColor: const Color(0xFF1565C0),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedTreatmentIds.add(t.id);
                                } else {
                                  selectedTreatmentIds.remove(t.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
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
                        String dentistId;
                        if (dentist == null) {
                          final newDentist = await _dentistService.addDentist(
                            name: nameCtrl.text,
                            specialization: specCtrl.text,
                            email: emailCtrl.text,
                            phone: phoneCtrl.text,
                            availableDays: daysCtrl.text,
                          );
                          dentistId = newDentist.id;
                        } else {
                          await _dentistService.updateDentist(
                            id: dentist.id,
                            name: nameCtrl.text,
                            specialization: specCtrl.text,
                            email: emailCtrl.text,
                            phone: phoneCtrl.text,
                            availableDays: daysCtrl.text,
                          );
                          dentistId = dentist.id;
                        }
                        await _dentistService.setDentistTreatments(
                          dentistId,
                          selectedTreatmentIds.toList(),
                        );
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
            'Are you sure you want to delete ${_formatDrName(dentist.name)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
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
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF1565C0)))
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
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _dentists.length,
                          separatorBuilder: (context, i) =>
                              Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final d = _dentists[index];
                            final assignedNames =
                                _dentistTreatmentsMap[d.id] ?? [];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 0),
                              shape: index == 0
                                  ? const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(12)))
                                  : index == _dentists.length - 1
                                      ? const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              bottom: Radius.circular(12)))
                                      : const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero),
                              elevation: 0,
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF1565C0)
                                          .withValues(alpha: 0.12),
                                      radius: 24,
                                      child: Text(
                                        d.name.isNotEmpty
                                            ? d.name[0].toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatDrName(d.name),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            d.specialization,
                                            style: const TextStyle(
                                                color: Color(0xFF1565C0),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.phone_outlined,
                                                  size: 12,
                                                  color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(d.phone,
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.email_outlined,
                                                  size: 12,
                                                  color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  d.email,
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_outlined,
                                                  size: 12,
                                                  color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(d.availableDays,
                                                  style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 11)),
                                            ],
                                          ),
                                          if (assignedNames.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .medical_services_outlined,
                                                    size: 12,
                                                    color:
                                                        Colors.teal[400]),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    assignedNames.join(', '),
                                                    style: TextStyle(
                                                        color: Colors.teal[600],
                                                        fontSize: 11),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Row(
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
                                          icon: const Icon(
                                              Icons.delete_rounded,
                                              color: Colors.red),
                                          onPressed: () => _deleteDentist(d),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
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
