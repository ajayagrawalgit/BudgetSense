import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/settings/profile_screen.dart';
import 'package:budgetsense/features/settings/settings_controller.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behavioural tests for the Profile screen (Settings > Profile).
///
/// The profile is the one place the app learns what to call the user, so the
/// tests check the full round trip: what was stored comes back into the fields,
/// what is typed survives a restart, and an age that is not a number is dropped
/// rather than written.

/// Persists a profile the way an earlier session would have, so the screen has
/// something real to load. Always resets storage first, so no test inherits
/// another one's profile.
Future<void> _seedProfile([
  SettingsState Function(SettingsState current)? patch,
]) async {
  SharedPreferences.setMockInitialValues({});
  if (patch == null) return;
  final container = ProviderContainer();
  await container.read(settingsControllerProvider.future);
  await container.read(settingsControllerProvider.notifier).save(patch);
  container.dispose();
}

/// Reads the profile back the way the next cold start would: from storage, with
/// a controller that has never seen the edits in memory.
Future<SettingsState> _reloadProfile() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(settingsControllerProvider.future);
}

Finder _input(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextField));

/// Stands in for the app shell: settings are already loaded before Profile is
/// reachable, and Profile is pushed on top of something the user can come back
/// to.
Widget _host() {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: Consumer(
        builder: (context, ref, _) {
          final loaded = ref.watch(settingsControllerProvider).hasValue;
          return Scaffold(
            body: Center(
              child: loaded
                  ? TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: const Text('Open profile'),
                    )
                  : const Text('Loading'),
            ),
          );
        },
      ),
    ),
  );
}

/// The form is taller than the 800x600 default test surface, so give the tests a
/// phone-shaped window where the Save button is genuinely tappable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open profile'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the stored profile is loaded into the form and survives a save',
      (tester) async {
    _useTallSurface(tester);
    await _seedProfile(
      (s) => s.copyWith(
        userName: 'Ajay',
        userNickname: 'AJ',
        userAge: 30,
        userPhone: '9876543210',
        userEmail: 'ajay@example.com',
      ),
    );

    await _openProfile(tester);
    expect(find.text('Ajay'), findsOneWidget);
    expect(find.text('AJ'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('ajay@example.com'), findsOneWidget);

    // Opening the screen and saving without editing must not quietly blank the
    // profile out.
    await _save(tester);
    final reloaded = await _reloadProfile();
    expect(reloaded.userName, 'Ajay');
    expect(reloaded.userNickname, 'AJ');
    expect(reloaded.userAge, 30);
    expect(reloaded.userPhone, '9876543210');
    expect(reloaded.userEmail, 'ajay@example.com');
  });

  testWidgets('saving edits keeps them after a restart and closes the screen',
      (tester) async {
    _useTallSurface(tester);
    await _seedProfile((s) => s.copyWith(userName: 'Ajay'));

    await _openProfile(tester);
    await tester.enterText(_input('First name'), '  Ajay Agrawal  ');
    await tester.enterText(_input('Nickname (optional)'), ' AJ ');
    await tester.enterText(_input('Age (optional)'), '31');
    await tester.enterText(_input('Email (optional)'), ' ajay@example.com ');
    await _save(tester);

    expect(find.text('Profile saved. Looking good.'), findsOneWidget);
    expect(
      find.text('Open profile'),
      findsOneWidget,
      reason: 'saving hands the user back to where they came from',
    );

    final reloaded = await _reloadProfile();
    expect(
      reloaded.userName,
      'Ajay Agrawal',
      reason: 'stray spaces are trimmed before they reach every greeting',
    );
    expect(reloaded.userNickname, 'AJ');
    expect(reloaded.userAge, 31);
    expect(reloaded.userEmail, 'ajay@example.com');
  });

  testWidgets('an age that is not a number is dropped, not stored',
      (tester) async {
    _useTallSurface(tester);
    await _seedProfile((s) => s.copyWith(userName: 'Ajay', userAge: 30));

    await _openProfile(tester);
    await tester.enterText(_input('Age (optional)'), 'thirty one');
    await tester.enterText(_input('Nickname (optional)'), 'AJ');
    await _save(tester);

    final reloaded = await _reloadProfile();
    expect(reloaded.userAge, isNull,
        reason: 'nonsense is never kept as an age');
    expect(
      reloaded.userNickname,
      'AJ',
      reason: 'the rest of the profile still saves',
    );
    expect(reloaded.userName, 'Ajay');
  });

  testWidgets('clearing the age removes it and it does not come back',
      (tester) async {
    _useTallSurface(tester);
    await _seedProfile((s) => s.copyWith(userName: 'Ajay', userAge: 30));

    await _openProfile(tester);
    await tester.enterText(_input('Age (optional)'), '');
    await _save(tester);

    expect((await _reloadProfile()).userAge, isNull);

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('30'),
      findsNothing,
      reason: 'reopening the form shows the age as cleared',
    );
  });
}
