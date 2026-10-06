import 'package:flutter/material.dart';

import 'patient_repository.dart';

Map<String, List<String>> fieldErrorsFrom(Object error) {
  final body = error is ApiException ? error.body : null;
  if (body == null) {
    return const <String, List<String>>{};
  }
  final errors = <String, List<String>>{};
  body.forEach((key, value) {
    if (value is String) {
      errors[key] = <String>[value];
    } else if (value is List<dynamic>) {
      final messages = value.whereType<String>().toList(growable: false);
      if (messages.isNotEmpty) {
        errors[key] = messages;
      }
    }
  });
  return errors;
}

String? firstFieldError(Map<String, List<String>> errors, String field) {
  final messages = errors[field];
  if (messages == null || messages.isEmpty) {
    return null;
  }
  return messages.first;
}

String? unhandledFieldError(Map<String, List<String>> errors, Set<String> handled) {
  for (final entry in errors.entries) {
    if (!handled.contains(entry.key) && entry.value.isNotEmpty) {
      return entry.value.first;
    }
  }
  return null;
}

class FieldErrorText extends StatelessWidget {
  const FieldErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
    );
  }
}
