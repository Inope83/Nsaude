import '../../../core/l10n/app_strings.dart';

abstract final class PatientLabels {
  static const String ageUnknown = '—';
  static const String age0To4 = '0–4';
  static const String age5To17 = '5–17';
  static const String age18To64 = '18–64';
  static const String age65Plus = '65+';

  static String ageGroup(DateTime? dateOfBirth) {
    if (dateOfBirth == null) {
      return ageUnknown;
    }
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;
    final hadBirthday = today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
    if (!hadBirthday) {
      age--;
    }
    if (age < 5) {
      return age0To4;
    }
    if (age < 18) {
      return age5To17;
    }
    if (age < 65) {
      return age18To64;
    }
    return age65Plus;
  }

  static String sex(String code) {
    switch (code) {
      case 'M':
        return AppStrings.male;
      case 'F':
        return AppStrings.female;
      case 'O':
        return AppStrings.other;
      default:
        return code;
    }
  }
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? _parseText(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class Patient {
  const Patient({
    required this.id,
    required this.patientId,
    required this.firstName,
    required this.lastName,
    required this.sex,
    required this.isActive,
    this.clientUuid,
    this.dateOfBirth,
    this.suco,
    this.sucoName,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? clientUuid;
  final String patientId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String sex;
  final int? suco;
  final String? sucoName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';
  String get ageGroup => PatientLabels.ageGroup(dateOfBirth);
  String get sexLabel => PatientLabels.sex(sex);

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as int,
        clientUuid: json['client_uuid'] as String?,
        patientId: json['patient_id'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        dateOfBirth: _parseDate(json['date_of_birth']),
        sex: json['sex'] as String? ?? '',
        suco: json['suco'] as int?,
        sucoName: json['suco_name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );
}

class PatientDetail extends Patient {
  const PatientDetail({
    required super.id,
    required super.patientId,
    required super.firstName,
    required super.lastName,
    required super.sex,
    required super.isActive,
    super.clientUuid,
    super.dateOfBirth,
    super.suco,
    super.sucoName,
    super.createdAt,
    super.updatedAt,
    this.phone,
    this.address,
    this.emergencyContact,
    this.administrativePost,
    this.municipality,
  });

  final String? phone;
  final String? address;
  final String? emergencyContact;
  final String? administrativePost;
  final String? municipality;

  factory PatientDetail.fromJson(Map<String, dynamic> json) => PatientDetail(
        id: json['id'] as int,
        clientUuid: json['client_uuid'] as String?,
        patientId: json['patient_id'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        dateOfBirth: _parseDate(json['date_of_birth']),
        sex: json['sex'] as String? ?? '',
        suco: json['suco'] as int?,
        sucoName: json['suco_name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        phone: _parseText(json['phone']),
        address: _parseText(json['address']),
        emergencyContact: _parseText(json['emergency_contact']),
        administrativePost: _parseText(json['administrative_post']),
        municipality: _parseText(json['municipality']),
      );
}

class PatientPage {
  const PatientPage(this.results, [this.next, this.count = 0]);

  final List<Patient> results;
  final String? next;
  final int count;
}

class MonitoringRecord {
  const MonitoringRecord({
    required this.id,
    required this.patient,
    this.clientUuid,
    this.recordedBy,
    this.recordedAt,
    this.temperature,
    this.heartRate,
    this.respiratoryRate,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.oxygenSaturation,
    this.symptoms,
    this.notes,
    this.createdAt,
  });

  final int id;
  final String? clientUuid;
  final int patient;
  final String? recordedBy;
  final DateTime? recordedAt;
  final double? temperature;
  final int? heartRate;
  final int? respiratoryRate;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? oxygenSaturation;
  final String? symptoms;
  final String? notes;
  final DateTime? createdAt;

  factory MonitoringRecord.fromJson(Map<String, dynamic> json) =>
      MonitoringRecord(
        id: json['id'] as int,
        clientUuid: json['client_uuid'] as String?,
        patient: json['patient'] as int,
        recordedBy: _parseText(json['recorded_by']),
        recordedAt: _parseDate(json['recorded_at']),
        temperature: (json['temperature'] as num?)?.toDouble(),
        heartRate: (json['heart_rate'] as num?)?.toInt(),
        respiratoryRate: (json['respiratory_rate'] as num?)?.toInt(),
        bloodPressureSystolic:
            (json['blood_pressure_systolic'] as num?)?.toInt(),
        bloodPressureDiastolic:
            (json['blood_pressure_diastolic'] as num?)?.toInt(),
        oxygenSaturation: (json['oxygen_saturation'] as num?)?.toInt(),
        symptoms: _parseText(json['symptoms']),
        notes: _parseText(json['notes']),
        createdAt: _parseDate(json['created_at']),
      );
}
