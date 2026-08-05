import 'package:budgetsense/features/settings/settings_controller.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('build returns defaults when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final c = makeContainer();
    final state = await c.read(settingsControllerProvider.future);
    expect(state.hapticsEnabled, isTrue);
    expect(state.userName, const SettingsState().userName);
  });

  test('save persists a transform and updates state', () async {
    SharedPreferences.setMockInitialValues({});
    final c = makeContainer();
    await c.read(settingsControllerProvider.future);

    await c.read(settingsControllerProvider.notifier).save(
          (s) => s.copyWith(hapticsEnabled: false, userName: 'Ajay'),
        );

    final state = c.read(settingsControllerProvider).requireValue;
    expect(state.hapticsEnabled, isFalse);
    expect(state.userName, 'Ajay');

    // A fresh controller (new build) must read the persisted value back.
    final c2 = makeContainer();
    final reloaded = await c2.read(settingsControllerProvider.future);
    expect(reloaded.hapticsEnabled, isFalse);
    expect(reloaded.userName, 'Ajay');
  });

  test('resetField restores a single field to its default', () async {
    SharedPreferences.setMockInitialValues({});
    final c = makeContainer();
    await c.read(settingsControllerProvider.future);
    final notifier = c.read(settingsControllerProvider.notifier);

    await notifier.save((s) => s.copyWith(hapticsEnabled: false));
    expect(c.read(settingsControllerProvider).requireValue.hapticsEnabled,
        isFalse);

    await notifier.resetField(
      (current, defaults) =>
          current.copyWith(hapticsEnabled: defaults.hapticsEnabled),
    );
    expect(
      c.read(settingsControllerProvider).requireValue.hapticsEnabled,
      isTrue,
    );
  });

  test('corrupt persisted JSON falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'budgetsense.settings.v1': 'this is not valid json',
    });
    final c = makeContainer();
    final state = await c.read(settingsControllerProvider.future);
    expect(state.hapticsEnabled, isTrue);
  });
}
