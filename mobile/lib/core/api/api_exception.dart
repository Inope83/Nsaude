import '../l10n/app_strings.dart';

class ApiException implements Exception {
  const ApiException(this.status, [this.body]);

  final int status;
  final Map<String, dynamic>? body;

  String get message {
    final detail = body?['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    return AppStrings.connectionError;
  }

  @override
  String toString() => 'ApiException($status)';
}