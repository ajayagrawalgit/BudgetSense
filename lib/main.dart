import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/cloud_providers.dart';

/// App entry point. Keeps almost no logic - composition happens in [App] and
/// the provider graph. Riverpod's [ProviderScope] owns all app-wide state.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
