// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the SuperLogManager functionality, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_super_log_manager/flutter_super_log_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SuperLogManager integration test', (WidgetTester tester) async {
    // Test that SuperLogManager can be initialized and used
    SuperLogManager.init();

    // Test adding logs
    SuperLogManager.instance.addLog(
      'Integration test log',
      level: LogLevel.info,
    );
    SuperLogManager.instance.addLog(
      'Integration test error',
      level: LogLevel.error,
    );

    // Test that logs are stored
    expect(SuperLogManager.instance.filteredLogs.length, 2);

    // Test error count
    expect(SuperLogManager.instance.errorCount, 1);

    // Test clearing logs
    SuperLogManager.instance.clearLogs();
    expect(SuperLogManager.instance.filteredLogs.length, 0);
  });
}
