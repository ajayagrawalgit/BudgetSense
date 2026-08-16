import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/cloud_providers.dart';

/// App entry point. Keeps almost no logic - composition happens in [App] and
/// the provider graph. Riverpod's [ProviderScope] owns all app-wide state.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerBundledFontLicenses();

  // Resolve SharedPreferences once so the cloud metadata store and mutation
  // tracker are available synchronously through the provider graph.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}

/// Flutter collects licences from pub packages on its own, but fonts declared
/// in `pubspec.yaml` are not covered. The bundled typefaces are under the SIL
/// Open Font License, which requires the notice to travel with them, so it is
/// registered here and shown on the About screen's licence page.
void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(
      const [
        'Zen Maru Gothic',
        'Caveat',
        'Patrick Hand',
        'Gochi Hand',
        "Architect's Daughter",
      ],
      text,
    );
  });
}
