import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_fonts.dart';
import 'package:budgetsense/core/theme/theme_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These are performance regressions dressed as equality tests.
///
/// `MaterialApp` decides whether to animate by comparing the `ThemeData` it was
/// handed against the previous one. If two identically-configured themes ever
/// compare unequal again, the app will animate a "change" that isn't one, and
/// the whole UI re-lays-out for the duration. That is exactly the stutter these
/// guard against, so please do not relax them.
void main() {
  group('AppColors equality', () {
    test('two identically-built palettes are equal', () {
      final a = AppColors.light(AccentPreset.clay.color);
      final b = AppColors.light(AccentPreset.clay.color);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('a different accent is a different palette', () {
      final clay = AppColors.light(AccentPreset.clay.color);
      final olive = AppColors.light(AccentPreset.olive.color);

      expect(clay, isNot(equals(olive)));
    });

    test('light and dark are never mistaken for each other', () {
      final light = AppColors.light(AccentPreset.clay.color);
      final dark = AppColors.dark(AccentPreset.clay.color);

      expect(light, isNot(equals(dark)));
    });

    test('glass tracks whether blur is actually supported', () {
      final blurred =
          AppColors.glass(AccentPreset.ink.color, blurSupported: true);
      final flat =
          AppColors.glass(AccentPreset.ink.color, blurSupported: false);

      expect(blurred, isNot(equals(flat)));
    });
  });

  group('ThemeResolver.resolvePair', () {
    test('identical inputs return the identical ThemeData instances', () {
      final first = ThemeResolver.resolvePair(
        variant: AppThemeVariant.system,
        accent: AccentPreset.clay,
        font: FontChoice.system,
      );
      final second = ThemeResolver.resolvePair(
        variant: AppThemeVariant.system,
        accent: AccentPreset.clay,
        font: FontChoice.system,
      );

      // Identity, not equality: a new-but-equal object still restarts the
      // theme animation, which is the thing being prevented here.
      expect(identical(first.light, second.light), isTrue);
      expect(identical(first.dark, second.dark), isTrue);
    });

    test('changing the font produces a new theme', () {
      final system = ThemeResolver.resolvePair(
        variant: AppThemeVariant.light,
        accent: AccentPreset.clay,
        font: FontChoice.system,
      );
      final caveat = ThemeResolver.resolvePair(
        variant: AppThemeVariant.light,
        accent: AccentPreset.clay,
        font: FontChoice.caveat,
      );

      expect(identical(system.light, caveat.light), isFalse);
      expect(caveat.light.textTheme.bodyLarge!.fontFamily, 'Caveat');
    });

    test('changing the accent produces a new theme', () {
      final clay = ThemeResolver.resolvePair(
        variant: AppThemeVariant.dark,
        accent: AccentPreset.clay,
      );
      final plum = ThemeResolver.resolvePair(
        variant: AppThemeVariant.dark,
        accent: AccentPreset.plum,
      );

      expect(identical(clay.dark, plum.dark), isFalse);
    });

    test('each variant maps to the mode it claims', () {
      ThemeMode modeOf(AppThemeVariant v) =>
          ThemeResolver.resolvePair(variant: v, accent: AccentPreset.clay).mode;

      expect(modeOf(AppThemeVariant.system), ThemeMode.system);
      expect(modeOf(AppThemeVariant.light), ThemeMode.light);
      expect(modeOf(AppThemeVariant.dark), ThemeMode.dark);
      expect(modeOf(AppThemeVariant.amoled), ThemeMode.dark);
      expect(modeOf(AppThemeVariant.glass), ThemeMode.dark);
    });

    test('single-brightness variants share one theme for light and dark', () {
      final amoled = ThemeResolver.resolvePair(
        variant: AppThemeVariant.amoled,
        accent: AccentPreset.ink,
      );

      expect(identical(amoled.light, amoled.dark), isTrue);
    });

    test('the palette survives the round trip into the theme extension', () {
      final theme = ThemeResolver.resolvePair(
        variant: AppThemeVariant.light,
        accent: AccentPreset.olive,
      ).light;

      expect(
        theme.extension<AppColors>()!.accent,
        AccentPreset.olive.color,
      );
    });
  });
}
