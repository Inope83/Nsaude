abstract final class EmergencyLabels {
  static const List<String> severities = <String>[
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];
  static const List<String> statuses = <String>[
    'OPEN',
    'IN_REVIEW',
    'ESCALATED',
    'RESOLVED',
  ];
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? _parseText(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class EmergencyCase {
  const EmergencyCase({
    required this.id,
    required this.patient,
    required this.severity,
    required this.status,
    this.clientUuid,
    this.createdBy,
    this.facility,
    this.symptoms,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? clientUuid;
  final int patient;
  final String? createdBy;
  final int? facility;
  final String severity;
  final String? symptoms;
  final String? description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EmergencyCase.fromJson(Map<String, dynamic> json) => EmergencyCase(
        id: json['id'] as int,
        clientUuid: json['client_uuid'] as String?,
        patient: json['patient'] as int,
        createdBy: _parseText(json['created_by']),
        facility: json['facility'] as int?,
        severity: json['severity'] as String? ?? '',
        symptoms: _parseText(json['symptoms']),
        description: _parseText(json['description']),
        status: json['status'] as String? ?? '',
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );
}

class EmergencyPage {
  const EmergencyPage(this.results, [this.next, this.count = 0]);

  final List<EmergencyCase> results;
  final String? next;
  final int count;
}