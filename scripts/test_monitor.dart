import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _heartbeatInterval = Duration(seconds: 15);
const _stuckThreshold = Duration(seconds: 30);

void main(List<String> args) async {
  final threadCount = args.isNotEmpty ? int.tryParse(args[0]) ?? '?' : '?';

  stderr.writeln('');
  stderr.writeln('┌─────────────────────────────────────────┐');
  stderr.writeln(
    '│  Running tests with $threadCount concurrent threads${_pad(threadCount)} │',
  );
  stderr.writeln('└─────────────────────────────────────────┘');
  stderr.writeln('');

  // suiteID -> file path
  final suites = <int, String>{};
  // testID -> display name
  final activeTests = <int, String>{};
  // testID -> slot number
  final testSlots = <int, int>{};
  // testID -> start time
  final testStartTimes = <int, DateTime>{};
  // currently free slot numbers
  final freeSlots = <int>{};
  var nextSlot = 1;

  var passed = 0;
  var failed = 0;
  var skipped = 0;
  var exitCode = 0;

  // Periodically print all still-running tests so stuck ones are visible in CI logs
  final heartbeat = Timer.periodic(_heartbeatInterval, (_) {
    if (activeTests.isEmpty) return;
    final now = DateTime.now();
    stderr.writeln('\n⏱  STILL RUNNING (${activeTests.length} active):');
    for (final entry in activeTests.entries) {
      final id = entry.key;
      final name = entry.value;
      final slot = testSlots[id] ?? '?';
      final elapsed = now.difference(testStartTimes[id] ?? now).inSeconds;
      final warn =
          elapsed >= _stuckThreshold.inSeconds ? '  ⚠️  POSSIBLY STUCK' : '';
      stderr.writeln('  [T$slot] ${elapsed}s  $name$warn');
    }
    stderr.writeln('');
  });

  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((line) {
    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = event['type'] as String?;

    switch (type) {
      case 'suite':
        final suite = event['suite'] as Map<String, dynamic>;
        final id = suite['id'] as int;
        final path = (suite['path'] as String?) ?? '?';
        suites[id] = _shortPath(path);

      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        final id = test['id'] as int;
        final name = (test['name'] as String?) ?? '';
        final suiteId = test['suiteID'] as int?;

        // Skip the synthetic "loading" tests dart test creates per file
        if (name.isEmpty || name.startsWith('loading ')) break;

        final file = suiteId != null ? (suites[suiteId] ?? '?') : '?';

        int slot;
        if (freeSlots.isNotEmpty) {
          slot = freeSlots.reduce((a, b) => a < b ? a : b);
          freeSlots.remove(slot);
        } else {
          slot = nextSlot++;
        }
        testSlots[id] = slot;
        activeTests[id] = name;
        testStartTimes[id] = DateTime.now();

        stderr.writeln('[T$slot] ▶ $name');
        stderr.writeln('       $file');

      case 'testDone':
        final testId = event['testID'] as int;
        final result = (event['result'] as String?) ?? 'error';
        final hidden = (event['hidden'] as bool?) ?? false;
        final wasSkipped = (event['skipped'] as bool?) ?? false;

        if (hidden) break;

        final name = activeTests.remove(testId) ?? '?';
        final slot = testSlots.remove(testId);
        if (slot != null) freeSlots.add(slot);
        final startTime = testStartTimes.remove(testId);
        final elapsed = startTime != null
            ? DateTime.now().difference(startTime).inSeconds
            : null;
        final elapsedLabel = elapsed != null ? ' (${elapsed}s)' : '';

        if (wasSkipped) {
          skipped++;
          stderr.writeln('[T${slot ?? '?'}] ⊘ SKIP$elapsedLabel: $name');
        } else if (result == 'success') {
          passed++;
          stderr.writeln('[T${slot ?? '?'}] ✓ PASS$elapsedLabel: $name');
        } else {
          failed++;
          exitCode = 1;
          stderr.writeln('[T${slot ?? '?'}] ✗ FAIL$elapsedLabel: $name');
        }

      case 'error':
        final testId = event['testID'] as int?;
        final error = (event['error'] as String?) ?? '';
        final stackTrace = (event['stackTrace'] as String?) ?? '';
        final slot = testId != null ? testSlots[testId] : null;
        stderr.writeln('[T${slot ?? '?'}] ✗ ERROR: $error');
        if (stackTrace.isNotEmpty) stderr.writeln(stackTrace);

      case 'done':
        final success = (event['success'] as bool?) ?? false;
        if (!success) exitCode = 1;
        stderr.writeln('');
        stderr.writeln(
          'Results: $passed passed, $failed failed, $skipped skipped',
        );
        stderr.writeln('');
    }
  });

  heartbeat.cancel();
  exit(exitCode);
}

String _shortPath(String path) {
  final idx = path.indexOf('/test/');
  if (idx >= 0) return path.substring(idx + 1);
  return path.split('/').last;
}

String _pad(Object threadCount) {
  final label = 'Running tests with $threadCount concurrent threads';
  const total = 41;
  final spaces = total - label.length;
  return spaces > 0 ? ' ' * spaces : '';
}
