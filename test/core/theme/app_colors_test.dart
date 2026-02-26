import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traxelos/core/theme/app_colors.dart';

void main() {
  group('AppColors.deviceColor', () {
    test('returns a color for each index 0-9 in light mode', () {
      for (int i = 0; i < 10; i++) {
        expect(AppColors.deviceColor(i, Brightness.light), isA<Color>());
      }
    });

    test('returns a color for each index 0-9 in dark mode', () {
      for (int i = 0; i < 10; i++) {
        expect(AppColors.deviceColor(i, Brightness.dark), isA<Color>());
      }
    });

    test('clamps out-of-range index', () {
      expect(AppColors.deviceColor(-1, Brightness.light), isA<Color>());
      expect(AppColors.deviceColor(99, Brightness.light), isA<Color>());
    });

    test('light and dark colors differ', () {
      final light = AppColors.deviceColor(0, Brightness.light);
      final dark = AppColors.deviceColor(0, Brightness.dark);
      expect(light, isNot(equals(dark)));
    });

    test('deviceColorTint has transparency', () {
      final tint = AppColors.deviceColorTint(0, Brightness.light);
      expect(tint.a, lessThan(1.0));
    });

    test('deviceColorOffline has reduced opacity', () {
      final offline = AppColors.deviceColorOffline(0, Brightness.light);
      expect(offline.a, lessThan(1.0));
      expect(offline.a, greaterThan(AppColors.deviceColorTint(0, Brightness.light).a));
    });

    test('all 10 colors are distinct in light mode', () {
      final colors = <Color>{};
      for (int i = 0; i < 10; i++) {
        colors.add(AppColors.deviceColor(i, Brightness.light));
      }
      expect(colors.length, 10);
    });
  });
}
