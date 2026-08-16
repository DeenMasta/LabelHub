import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/app/theme/app_theme.dart';

void main() {
  test('uses the dark-blue primary colour across the app theme', () {
    expect(AppTheme.primary, const Color(0xFF2D323D));
    expect(AppTheme.light.colorScheme.primary, AppTheme.primary);
  });
}
