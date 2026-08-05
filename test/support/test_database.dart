import 'package:budgetsense/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Shared helpers for tests that need a real (but ephemeral) database.
///
/// Every test gets its OWN in-memory SQLite database so suites never share
/// mutable global state and cannot leak rows into one another.
///
/// We also flip [driftRuntimeOptions.dontWarnAboutMultipleDatabases] once here.
/// Drift warns when the same database class is instantiated more than once in a
/// single isolate, which is exactly what a healthy test suite does (a fresh DB
/// per `setUp`). The warning is noise in that context and was cluttering the
/// test log; silencing it at the source is the drift-recommended approach for
/// tests. It changes nothing about production behaviour.
bool _warningsSilenced = false;

AppDatabase newTestDatabase() {
  if (!_warningsSilenced) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _warningsSilenced = true;
  }
  return AppDatabase.forTesting(NativeDatabase.memory());
}
