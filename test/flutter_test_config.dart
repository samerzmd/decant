import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in `test/`.
///
/// Goldens are made on macOS but CI runs on Linux, where anti-aliasing can
/// land a few edge pixels differently. Allow that much, and no more.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final base = goldenFileComparator;
  if (base is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      base.basedir.resolve('golden_test.dart'),
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// Largest share of pixels allowed to differ (0.5%).
  static const double tolerance = 0.005;

  /// Goldens drawn through fragment shaders, whose trig functions round a
  /// little differently on each GPU backend, get 1%.
  static const double shaderTolerance = 0.01;
  static const _shaderGoldens = {'tubes_refracted.png'};

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final limit = _shaderGoldens.contains(golden.pathSegments.last)
        ? shaderTolerance
        : tolerance;
    if (result.passed || result.diffPercent <= limit) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
