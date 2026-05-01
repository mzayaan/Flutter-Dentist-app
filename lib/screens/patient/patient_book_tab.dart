import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/dentist.dart';
import '../../models/patient.dart';
import '../../models/treatment.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../services/dentist_service.dart';

String _formatDrName(String name) {
  return name.startsWith('Dr.') ? name : 'Dr. $name';
}

const Map<String, int> _dayMap = {
  'Mon': DateTime.monday,
  'Tue': DateTime.tuesday,
  'Wed': DateTime.wednesday,
  'Thu': DateTime.thursday,
  'Fri': DateTime.friday,
  'Sat': DateTime.saturday,
  'Sun': DateTime.sunday,
};

class PatientBookTab extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onBookingComplete;

  const PatientBookTab({
    super.key,
    required this.patient,
    this.onBookingComplete,
  });

  @override
  State<PatientBookTab> createState() => _PatientBookTabState();
}

class _PatientBookTabState extends State<PatientBookTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  final _dentistService = DentistService();
  final _appointmentService = AppointmentService();
  final _billService = BillService();

  int _step = 0;

  // Step 1 — Dentist
  List<Dentist> _dentists = [];
  List<Dentist> _filteredDentists = [];
  Dentist? _selectedDentist;
  final _searchCtrl = TextEditingController();
  bool _loadingDentists = true;
  List<int> _workingDays = [];

  // Step 2 — Treatment (filtered by dentist)
  List<Treatment> _treatments = [];
  Treatment? _selectedTreatment;
  bool _loadingTreatments = false;

  // Step 3 — Date
  DateTime? _selectedDate;

  // Step 4 — Time slots + Notes
  late final List<String> _allSlots;
  List<String> _bookedSlots = [];
  String? _selectedTime;
  bool _loadingSlots = false;
  final _notesCtrl = TextEditingController();

  bool _booking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _allSlots = _generateTimeSlots();
    _loadDentists();
    _searchCtrl.addListener(_filterDentists);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Slot generation ──────────────────────────────────────────────────────

  List<String> _generateTimeSlots() {
    final slots = <String>[];
    for (int hour = 9; hour < 17; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      slots.add('${hour.toString().padLeft(2, '0')}:30');
    }
    return slots; // 09:00 … 16:30 (16 slots)
  }

  // ── Working days ─────────────────────────────────────────────────────────

  List<int> _parseWorkingDays(String availableDays) {
    return availableDays
        .split(',')
        .map((d) => _dayMap[d.trim()] ?? 0)
        .where((d) => d != 0)
        .toList();
  }

  DateTime _getNextWorkingDay(List<int> workingDays) {
    var day = DateTime.now().add(const Duration(days: 1));
    while (!workingDays.contains(day.weekday)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  // ── Data loaders ─────────────────────────────────────────────────────────

  Future<void> _loadDentists() async {
    setState(() => _loadingDentists = true);
    try {
      final list = await _dentistService.getAllDentists();
      if (!mounted) return;
      setState(() {
        _dentists = list;
        _filteredDentists = list;
        _loadingDentists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDentists = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterDentists() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredDentists = _dentists.where((d) {
        return d.name.toLowerCase().contains(q) ||
            d.specialization.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _loadDentistTreatments() async {
    if (_selectedDentist == null) return;
    setState(() => _loadingTreatments = true);
    try {
      final rows = await _supabase
          .from('dentist_treatments')
          .select('treatments(*)')
          .eq('dentist_id', _selectedDentist!.id) as List;
      if (!mounted) return;
      setState(() {
        _treatments = rows
            .map((e) =>
                Treatment.fromJson(e['treatments'] as Map<String, dynamic>))
            .toList();
        _loadingTreatments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTreatments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedDentist == null || _selectedDate == null) return;
    setState(() {
      _loadingSlots = true;
      _bookedSlots = [];
    });
    final dateStr = _selectedDate!.toIso8601String().split('T')[0];
    try {
      final slots = await _appointmentService.getBookedSlots(
          _selectedDentist!.id, dateStr);
      if (!mounted) return;
      setState(() {
        _bookedSlots = slots;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final initialDate = _workingDays.isEmpty
        ? DateTime.now().add(const Duration(days: 1))
        : _getNextWorkingDay(_workingDays);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      selectableDayPredicate: _workingDays.isEmpty
          ? null
          : (day) => _workingDays.contains(day.weekday),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
        _bookedSlots = [];
      });
    }
  }

  // ── Booking ───────────────────────────────────────────────────────────────

  Future<void> _showConfirmationDialog() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Appointment',
          style: TextStyle(
              color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryDialogRow(Icons.person_outline, 'Dentist',
                _formatDrName(_selectedDentist!.name)),
            _summaryDialogRow(Icons.star_outline, 'Specialization',
                _selectedDentist!.specialization),
            _summaryDialogRow(Icons.medical_services_outlined, 'Treatment',
                _selectedTreatment!.name),
            const Divider(height: 20),
            _summaryDialogRow(
              Icons.calendar_today_outlined,
              'Date',
              DateFormat('EEEE, dd MMM yyyy').format(_selectedDate!),
            ),
            _summaryDialogRow(
                Icons.access_time_outlined, 'Time', _selectedTime!),
            const Divider(height: 20),
            _summaryDialogRow(
              Icons.currency_rupee_rounded,
              'Amount',
              'Rs ${_selectedTreatment!.price.toStringAsFixed(2)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _saveAppointment();
  }

  Future<void> _saveAppointment() async {
    setState(() => _booking = true);
    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];

      // Final server-side double-booking check
      final conflicts = await _supabase
          .from('appointments')
          .select('id')
          .eq('dentist_id', _selectedDentist!.id)
          .eq('appointment_date', dateStr)
          .eq('appointment_time', _selectedTime!)
          .neq('status', 'Cancelled') as List;

      if (!mounted) return;
      if (conflicts.isNotEmpty) {
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sorry! This slot was just booked by someone else. '
              'Please select another time.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        await _loadBookedSlots();
        return;
      }

      // Check patient doesn't already have appointment this date
      final hasConflict = await _appointmentService.hasPendingOnDate(
          widget.patient.id, _selectedDate!);
      if (!mounted) return;
      if (hasConflict) {
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have a pending appointment on this date. '
              'Please choose a different date.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final appt = await _appointmentService.bookAppointment(
        patientId: widget.patient.id,
        dentistId: _selectedDentist!.id,
        treatmentId: _selectedTreatment!.id,
        appointmentDate: _selectedDate!,
        appointmentTime: _selectedTime!,
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await _billService.createBill(
        appointmentId: appt.id,
        patientId: widget.patient.id,
        totalAmount: _selectedTreatment!.price,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Appointment booked! A bill has been created.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _step = 0;
        _selectedDentist = null;
        _selectedTreatment = null;
        _selectedDate = null;
        _selectedTime = null;
        _bookedSlots = [];
        _treatments = [];
        _workingDays = [];
        _notesCtrl.clear();
        _searchCtrl.clear();
        _filteredDentists = _dentists;
        _booking = false;
      });

      widget.onBookingComplete?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(currentStep: _step, totalSteps: 4),
          const SizedBox(height: 24),
          if (_step == 0) _buildStep1(),
          if (_step == 1) _buildStep2(),
          if (_step == 2) _buildStep3(),
          if (_step == 3) _buildStep4(),
        ],
      ),
    );
  }

  // ── Step 1: Dentist ───────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Choose a Dentist',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by name or specialization...',
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFF1565C0)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF1565C0), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingDentists)
          const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF1565C0)))
        else if (_filteredDentists.isEmpty)
          Center(
            child: Text('No dentists found',
                style: TextStyle(color: Colors.grey[600])),
          )
        else
          ...(_filteredDentists.map((d) => _DentistCard(
                dentist: d,
                selected: _selectedDentist?.id == d.id,
                onTap: () => setState(() => _selectedDentist = d),
              ))),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedDentist == null
                ? null
                : () {
                    setState(() {
                      _step = 1;
                      _selectedTreatment = null;
                      _treatments = [];
                      _workingDays = _parseWorkingDays(
                          _selectedDentist!.availableDays);
                    });
                    _loadDentistTreatments();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text('Next: Choose Treatment',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Treatment (filtered) ──────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Choose a Treatment',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDrName(_selectedDentist?.name ?? ''),
          style: const TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        if (_loadingTreatments)
          const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF1565C0)))
        else if (_treatments.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No treatments assigned to this dentist yet.\n'
                    'Please contact the clinic.',
                    style: TextStyle(
                        color: Colors.orange[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ...(_treatments.map((t) => _TreatmentCard(
                treatment: t,
                selected: _selectedTreatment?.id == t.id,
                onTap: () => setState(() => _selectedTreatment = t),
              ))),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedTreatment == null
                    ? null
                    : () => setState(() {
                          _step = 2;
                          _selectedDate = null;
                          _selectedTime = null;
                          _bookedSlots = [];
                        }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text('Next: Pick Date',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Date ──────────────────────────────────────────────────────────

  Widget _buildStep3() {
    final dayNames = _workingDays
        .map((wd) =>
            _dayMap.entries.firstWhere((e) => e.value == wd).key)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Pick a Date',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null
                    ? const Color(0xFF1565C0)
                    : Colors.grey[300]!,
                width: _selectedDate != null ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF1565C0), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'Select Appointment Date'
                            : DateFormat('EEEE, dd MMMM yyyy')
                                .format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedDate != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedDate != null
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey[500],
                        ),
                      ),
                      if (_selectedDate == null)
                        Text(
                          'Tap to open calendar',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
        if (dayNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: Colors.teal[600]),
              const SizedBox(width: 6),
              Text(
                'Available days: $dayNames',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.teal[600],
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedDate == null
                    ? null
                    : () {
                        setState(() {
                          _step = 3;
                          _selectedTime = null;
                          _bookedSlots = [];
                          _loadingSlots = true;
                        });
                        _loadBookedSlots();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text('Next: Pick Time',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: Time Slots + Notes ────────────────────────────────────────────

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Choose a Time Slot',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 12),

        // Mini summary
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                const Color(0xFF1565C0).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDrName(_selectedDentist!.name)} · '
                  '${_selectedTreatment!.name} · '
                  '${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_loadingSlots)
          const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: Color(0xFF1565C0)),
          ))
        else ...[
          // Slot grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _allSlots.length,
            itemBuilder: (context, index) {
              final slot = _allSlots[index];
              final isBooked = _bookedSlots.contains(slot);
              final isSelected = _selectedTime == slot;
              return GestureDetector(
                onTap: isBooked
                    ? null
                    : () => setState(() => _selectedTime = slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.red[50]
                        : isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isBooked
                          ? Colors.red[300]!
                          : isSelected
                              ? const Color(0xFF1565C0)
                              : Colors.green[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      slot,
                      style: TextStyle(
                        color: isBooked
                            ? Colors.red[700]
                            : isSelected
                                ? Colors.white
                                : Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _legendBox(Colors.green[50]!, Colors.green[300]!,
                  Colors.green[700]!, 'Available'),
              const SizedBox(width: 14),
              _legendBox(
                  Colors.red[50]!, Colors.red[300]!, Colors.red[700]!, 'Booked'),
              const SizedBox(width: 14),
              _legendBox(const Color(0xFF1565C0),
                  const Color(0xFF1565C0), Colors.white, 'Selected'),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Notes field
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'Any special requests or medical concerns...',
            prefixIcon:
                const Icon(Icons.notes_rounded, color: Color(0xFF1565C0)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF1565C0), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _step = 2;
                  _selectedTime = null;
                  _bookedSlots = [];
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                    (_selectedTime == null || _booking || _loadingSlots)
                        ? null
                        : _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _booking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Review & Book',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _legendBox(
      Color bg, Color border, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _summaryDialogRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator(
      {required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final labels = ['Dentist', 'Treatment', 'Date', 'Time'];
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        final current = i == currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? const Color(0xFF1565C0)
                            : Colors.grey[200],
                        border: current
                            ? Border.all(
                                color: const Color(0xFF1565C0), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: active && !current
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? const Color(0xFF1565C0)
                            : Colors.grey[400],
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < currentStep
                        ? const Color(0xFF1565C0)
                        : Colors.grey[200],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DentistCard extends StatelessWidget {
  final Dentist dentist;
  final bool selected;
  final VoidCallback onTap;

  const _DentistCard(
      {required this.dentist,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1565C0).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF1565C0)
                : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  const Color(0xFF1565C0).withValues(alpha: 0.12),
              radius: 22,
              child: Text(
                dentist.name.isNotEmpty
                    ? dentist.name[0].toUpperCase()
                    : 'D',
                style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDrName(dentist.name),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    dentist.specialization,
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    dentist.availableDays,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1565C0), size: 24),
          ],
        ),
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  final Treatment treatment;
  final bool selected;
  final VoidCallback onTap;

  const _TreatmentCard(
      {required this.treatment,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1565C0).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF1565C0)
                : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services_rounded,
                  color: Colors.teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    treatment.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    treatment.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Rs ${treatment.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        ' · ${treatment.durationMins} mins',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1565C0), size: 24),
          ],
        ),
      ),
    );
  }
}
