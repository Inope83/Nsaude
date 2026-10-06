abstract final class ReferralLabels {
  static const List<String> urgencies = <String>[
    'ROUTINE',
    'URGENT',
    'EMERGENCY',
  ];
  static const List<String> statuses = <String>[
    'PENDING',
    'ACCEPTED',
    'IN_TRANSIT',
    'COMPLETED',
    'CANCELLED',
  ];
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? _parseText(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class Referral {
  const Referral({
    required this.id,
    required this.patient,
    required this.urgency,
    required this.status,
    this.clientUuid,
    this.emergencyCase,
    this.referredBy,
    this.sourceFacility,
    this.destinationFacility,
    this.reason,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? clientUuid;
  final int patient;
  final int? emergencyCase;
  final String? referredBy;
  final int? sourceFacility;
  final int? destinationFacility;
  final String? reason;
  final String urgency;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Referral.fromJson(Map<String, dynamic> json) => Referral(
        id: json['id'] as int,
        clientUuid: json['client_uuid'] as String?,
        patient: json['patient'] as int,
        emergencyCase: json['emergency_case'] as int?,
        referredBy: _parseText(json['referred_by']),
        sourceFacility: json['source_facility'] as int?,
        destinationFacility: json['destination_facility'] as int?,
        reason: _parseText(json['reason']),
        urgency: json['urgency'] as String? ?? '',
        status: json['status'] as String? ?? '',
        notes: _parseText(json['notes']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );
}

class ReferralPage {
  const ReferralPage(this.results, [this.next, this.count = 0]);

  final List<Referral> results;
  final String? next;
  final int count;
}