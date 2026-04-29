class Appointment {
  final String id;
  final String patientId;
  final String dentistId;
  final String treatmentId;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  // Joined fields from select with foreign tables
  final String? patientName;
  final String? dentistName;
  final String? treatmentName;
  final double? treatmentPrice;

  Appointment({
    required this.id,
    required this.patientId,
    required this.dentistId,
    required this.treatmentId,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    this.notes,
    this.createdAt,
    this.patientName,
    this.dentistName,
    this.treatmentName,
    this.treatmentPrice,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final patientsMap = json['patients'] as Map<String, dynamic>?;
    final dentistsMap = json['dentists'] as Map<String, dynamic>?;
    final treatmentsMap = json['treatments'] as Map<String, dynamic>?;

    return Appointment(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      dentistId: json['dentist_id'] as String,
      treatmentId: json['treatment_id'] as String,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      appointmentTime: json['appointment_time'] as String,
      status: json['status'] as String? ?? 'Pending',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      patientName: patientsMap?['full_name'] as String?,
      dentistName: dentistsMap?['name'] as String?,
      treatmentName: treatmentsMap?['name'] as String?,
      treatmentPrice: treatmentsMap?['price'] != null
          ? (treatmentsMap!['price'] as num).toDouble()
          : null,
    );
  }
}
