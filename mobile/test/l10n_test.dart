import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI widgets do not contain hardcoded string literals', () {
    final literalArguments = <RegExp>[
      RegExp(r'''Text\s*\(\s*["']([^"']*)["']''', dotAll: true),
      RegExp(r'''(?:hintText|labelText|helperText|semanticLabel)\s*:\s*["']([^"']*)["']''',
          dotAll: true),
      RegExp(r'''Tooltip\s*\(\s*message:\s*["']([^"']*)["']''',
          dotAll: true),
    ];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('app_strings.dart') ||
          entity.path.endsWith('.g.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final pattern in literalArguments) {
        for (final match in pattern.allMatches(source)) {
          final literal = match.group(1) ?? '';
          if (!literal.contains(r'$')) {
            throw StateError(
              'Hardcoded UI string "$literal" in ${entity.path}: '
              'move it to AppStrings.',
            );
          }
        }
      }
    }
  });
}