import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dentist.dart';
import '../../models/patient.dart';
import '../../models/treatment.dart';
import '../../services/appointment_service.dart';
import '../../services/bill_service.dart';
import '../../services/dentist_service.dart';
import '../../services/treatment_service.dart';

class PatientBookTab extends StatefulWidget {
  final Patient patient;

  const PatientBookTab({super.key, required this.patient});

  @override
  State<PatientBookTab> createState() => _PatientBookTabState();
}

class _PatientBookTabState extends State<PatientBookTab> {
  final _dentistService = DentistService();
  final _treatmentService = TreatmentService();
  final _appointmentService = AppointmentService();
  final _billService = BillService();

  int _step = 0;

  // Step 1: Dentist
  List<Dentist> _dentists = [];
  List<Dentist> _filteredDentists = [];
  Dentist? _selectedDentist;
  final _searchCtrl = TextEditingController();
  bool _loadingDentists = true;

  // Step 2: Treatment
  List<Treatment> _treatments = [];
  Treatment? _selectedTreatment;
  bool _loadingTreatments = false;

  // Step 3: Date
  DateTime? _selectedDate;

  // Step 4: Time + Notes
  final _timeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _loadDentists();
    _searchCtrl.addListener(_filterDentists);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _loadTreatments() async {
    setState(() => _loadingTreatments = true);
    try {
      final list = await _treatmentService.getAllTreatments();
      if (!mounted) return;
      setState(() {
        _treatments = list;
        _loadingTreatments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTreatments = false);
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirmBooking() async {
    if (_timeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your preferred appointment time.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      // Check duplicate pending appointment
      final hasConflict = await _appointmentService.hasPendingOnDate(
        widget.patient.id,
        _selectedDate!,
      );
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
        appointmentTime: _timeCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await _billService.createBill(
        appointmentId: appt.id,
        patientId: widget.patient.id,
        totalAmount: _selectedTreatment!.price,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully! A bill has been created.'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      setState(() {
        _step = 0;
        _selectedDentist = null;
        _selectedTreatment = null;
        _selectedDate = null;
        _timeCtrl.clear();
        _notesCtrl.clear();
        _searchCtrl.clear();
        _booking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Center(child: CircularProgressIndicator(
              color: Color(0xFF1565C0)))
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
                    _loadTreatments();
                    setState(() => _step = 1);
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
        const SizedBox(height: 16),
        if (_loadingTreatments)
          const Center(child: CircularProgressIndicator(
              color: Color(0xFF1565C0)))
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
                    : () => setState(() => _step = 2),
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

  Widget _buildStep3() {
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
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha:0.1),
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
                    : () => setState(() => _step = 3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text('Next: Time & Notes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Time & Notes',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 16),
        _BookingSummaryCard(
          dentist: _selectedDentist!,
          treatment: _selectedTreatment!,
          date: _selectedDate!,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _timeCtrl,
          decoration: InputDecoration(
            labelText: 'Preferred Time',
            hintText: 'e.g. 10:30 AM, 2:00 PM',
            prefixIcon: const Icon(Icons.access_time_rounded,
                color: Color(0xFF1565C0)),
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
        const SizedBox(height: 14),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'Any special requests or medical concerns...',
            prefixIcon: const Icon(Icons.notes_rounded,
                color: Color(0xFF1565C0)),
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
                onPressed: () => setState(() => _step = 2),
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
                onPressed: _booking ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _booking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Booking',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator(
      {required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final labels = ['Dentist', 'Treatment', 'Date', 'Confirm'];
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
              ? const Color(0xFF1565C0).withValues(alpha:0.06)
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
                color: Colors.black.withValues(alpha:0.04),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  const Color(0xFF1565C0).withValues(alpha:0.12),
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
                    'Dr. ${dentist.name}',
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
              ? const Color(0xFF1565C0).withValues(alpha:0.06)
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
                color: Colors.teal.withValues(alpha:0.12),
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
                        '\$${treatment.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      Text(
                        ' • ${treatment.durationMins} mins',
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

class _BookingSummaryCard extends StatelessWidget {
  final Dentist dentist;
  final Treatment treatment;
  final DateTime date;

  const _BookingSummaryCard(
      {required this.dentist,
      required this.treatment,
      required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Summary',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
                fontSize: 14),
          ),
          const Divider(height: 16),
          _row('Dentist', 'Dr. ${dentist.name}'),
          _row('Treatment', treatment.name),
          _row('Date',
              DateFormat('EEE, dd MMM yyyy').format(date)),
          _row('Price', '\$${treatment.price.toStringAsFixed(2)}'),
          _row('Duration', '${treatment.durationMins} minutes'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
