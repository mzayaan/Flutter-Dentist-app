class Bill {
  final String id;
  final String appointmentId;
  final String patientId;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;

  // Joined fields
  final String? patientName;
  final String? appointmentDate;

  Bill({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.totalAmount,
    required this.status,
    this.createdAt,
    this.patientName,
    this.appointmentDate,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final patientsMap = json['patients'] as Map<String, dynamic>?;
    final appointmentsMap = json['appointments'] as Map<String, dynamic>?;

    return Bill(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      patientId: json['patient_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'Unpaid',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      patientName: patientsMap?['full_name'] as String?,
      appointmentDate: appointmentsMap?['appointment_date'] as String?,
    );
  }
}
