import 'package:flutter/material.dart';
import 'package:flutter_super_log_manager/flutter_super_log_manager.dart';

void main() {
  // Initialize the app with SuperLogManager
  SuperLogManager.runApp(
    const MyApp(),
    config: SuperLogConfig(
      enabled: true,
      showOverlayBubble: true,
      capturePrint: true,
      captureDebugPrint: true,
      maxLogs: 1000,

      initialBubblePosition: const Offset(16.0, 100.0),
      enableLogSearch: true,
      enableLogFiltering: true,
      enableLogDeletion: true,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Log Manager Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
      // Use SuperDebugWrapper.builder to inject bubble with Navigator context
      // builder: SuperDebugWrapper.builder,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  bool _isDelayedPrintRunning = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });

    // Add a log when counter changes
    SuperLogManager.instance.addLog(
      'Counter incremented to $_counter',
      level: LogLevel.info,
      tag: 'COUNTER',
    );
  }

  void _simulateError() {
    try {
      // Simulate an error
      throw Exception('This is a simulated error for testing');
    } catch (e, stackTrace) {
      // This error will be automatically caught by SuperLogManager
      // But we can also log it manually
      SuperLogManager.instance.addLog(
        'Simulated error occurred',
        level: LogLevel.error,
        error: e,
        stackTrace: stackTrace,
        tag: 'TEST',
      );
    }
  }

  void _addDebugLogs() {
    // Add various types of logs
    SuperLogManager.instance.addLog(
      'This is an info message',
      level: LogLevel.info,
      tag: 'EXAMPLE',
    );

    SuperLogManager.instance.addLog(
      'This is a warning message',
      level: LogLevel.warning,
      tag: 'EXAMPLE',
    );

    SuperLogManager.instance.addLog(
      'This is a debug message',
      level: LogLevel.debug,
      tag: 'EXAMPLE',
    );

    SuperLogManager.instance.addLog(
      'This is an error message',
      level: LogLevel.error,
      tag: 'EXAMPLE',
    );
  }

  void _testPrintCapture() {
    // These will be captured by SuperLogManager
    debugPrint('This is a print() call that will be logged');
  }

  void _tesDebugPrintCapture() {
    // These will be captured by SuperLogManager
    debugPrint('This is a debugPrint() call that will be logged');
  }

  Future<void> _simulateDelayedPrints({int times = 5}) async {
    if (_isDelayedPrintRunning) return;
    setState(() => _isDelayedPrintRunning = true);
    try {
      for (var i = 1; i <= times; i++) {
        final message =
            'Simulated delayed debugPrint $i/$times at ${DateTime.now().toIso8601String()}';
        debugPrint(message);
        if (i < times) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDelayedPrintRunning = false);
      } else {
        _isDelayedPrintRunning = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Log Manager Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {},
            tooltip: 'Open Debug Logs',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _incrementCounter,
              icon: const Icon(Icons.add),
              label: const Text('Increment Counter'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _simulateError,
              icon: const Icon(Icons.error),
              label: const Text('Simulate Error'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addDebugLogs,
              icon: const Icon(Icons.message),
              label: const Text('Add Test Logs'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _testPrintCapture,
              icon: const Icon(Icons.print),
              label: const Text('Test Print Capture'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _tesDebugPrintCapture,
              icon: const Icon(Icons.print),
              label: const Text('Test Debug Print Capture'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isDelayedPrintRunning
                  ? null
                  : () => _simulateDelayedPrints(times: 5),
              icon: const Icon(Icons.timer),
              label: Text(
                _isDelayedPrintRunning
                    ? 'Running Delayed Prints...'
                    : 'Simulate Delayed Prints (x5)',
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Tap the debug bubble (bottom corner) to view logs',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
