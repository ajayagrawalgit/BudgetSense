import 'package:budgetsense/app/update_providers.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/data/updates/update_manifest.dart';
import 'package:budgetsense/data/updates/update_service.dart';
import 'package:budgetsense/features/updates/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_cloud.dart';
import '../support/fake_updates.dart';

UpdateService _service({UpdateManifest? manifest}) => UpdateService(
      gateway: FakeUpdateGateway(manifest: manifest),
      installer: FakeApkInstaller(),
      store: InMemoryKeyValueStore(),
      currentVersionCode: () async => 1,
      downloadDirectory: () async => '.',
    );

Widget _host(UpdateService s) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [updateServiceProvider.overrideWithValue(s)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const Scaffold(body: UpdateBanner()),
    ),
  );
}

void main() {
  testWidgets('banner is hidden when there is no update', (tester) async {
    final s = _service();
    addTearDown(s.dispose);
    await tester.pumpWidget(_host(s));
    expect(find.text('A new version is ready'), findsNothing);
    expect(find.text('Update now'), findsNothing);
  });

  testWidgets('banner appears for an available update and can be dismissed',
      (tester) async {
    final m = UpdateManifest(
      versionCode: 3,
      versionName: '0.2.0',
      apkUrl: 'https://example.com/app.apk',
      sha256: 'a' * 64,
      notes: 'Nice things',
    );
    final s = _service(manifest: m);
    addTearDown(s.dispose);
    await s.checkForUpdate();
    await tester.pumpWidget(_host(s));
    await tester.pump();

    expect(find.text('A new version is ready'), findsOneWidget);
    expect(find.text('v0.2.0'), findsOneWidget);
    expect(find.textContaining('No rush'), findsOneWidget); // non-forcing tone

    await tester.tap(find.text('Maybe later'));
    await tester.pump();
    expect(find.text('A new version is ready'), findsNothing); // gone
    expect(s.state.status, UpdateStatus.idle);
  });
}
