import 'package:budgetsense/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Closes [db] in a widget test that subscribed to a drift stream.
///
/// Cancelling a drift query stream posts a zero-duration timer, and under
/// `testWidgets` that timer only fires while the fake clock is being advanced.
/// `close()` awaits it, so closing from a plain `addTearDown(db.close)` waits
/// for a timer that nothing will ever run, and the test hangs forever rather
/// than failing. Pumping once drains the timer, and only then is it safe to
/// close.
///
/// Use this instead of `addTearDown(db.close)` in any test that pumps a widget
/// watching the database.
Future<void> closeTestDatabase(WidgetTester tester, AppDatabase db) async {
  await tester.pump(Duration.zero);
  await db.close();
}

/// Registers [db] to be closed safely once the test finishes.
///
/// The drop-in replacement for `addTearDown(db.close)` in a `testWidgets`
/// body. See [closeTestDatabase] for why the pump is required.
void closeTestDatabaseOnTearDown(WidgetTester tester, AppDatabase db) {
  addTearDown(() => closeTestDatabase(tester, db));
}
