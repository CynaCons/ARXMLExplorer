import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Collects real `FrameTiming` samples from the engine.
///
/// This is the number that actually decides whether scrolling feels smooth.
/// The widget-test benchmarks measure `pump()` cost inside `flutter_tester`
/// with software rendering and fake async — useful for relative comparisons,
/// but blind to raster cost and to real frame scheduling. Running under
/// `integration_test` on a real desktop window, `addTimingsCallback` reports
/// what the engine genuinely did.
class FrameStats {
  FrameStats(this.label);

  final String label;
  final List<FrameTiming> _timings = <FrameTiming>[];
  TimingsCallback? _callback;

  /// 60fps budget. A frame over this dropped.
  static const double budgetMs = 1000 / 60;

  void start() {
    _timings.clear();
    _callback = (List<FrameTiming> t) => _timings.addAll(t);
    WidgetsBinding.instance.addTimingsCallback(_callback!);
  }

  void stop() {
    if (_callback != null) {
      WidgetsBinding.instance.removeTimingsCallback(_callback!);
      _callback = null;
    }
  }

  int get frameCount => _timings.length;

  List<double> _msOf(Duration Function(FrameTiming) pick) =>
      _timings.map((t) => pick(t).inMicroseconds / 1000.0).toList()..sort();

  List<double> get buildMs => _msOf((t) => t.buildDuration);
  List<double> get rasterMs => _msOf((t) => t.rasterDuration);

  /// Build + raster, the wall-clock cost of producing a frame.
  List<double> get totalMs {
    final v = _timings
        .map((t) =>
            (t.buildDuration.inMicroseconds + t.rasterDuration.inMicroseconds) /
            1000.0)
        .toList()
      ..sort();
    return v;
  }

  static double percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  /// Frames that missed the 60fps budget.
  int get jankFrames => totalMs.where((m) => m > budgetMs).length;

  /// Frames that took longer than four budgets — visible hitches.
  int get severeJankFrames => totalMs.where((m) => m > budgetMs * 4).length;

  double get jankPercent =>
      frameCount == 0 ? 0 : jankFrames * 100.0 / frameCount;

  double get worstMs => totalMs.isEmpty ? 0 : totalMs.last;

  String report() {
    if (_timings.isEmpty) return '$label: no frames captured';
    final t = totalMs;
    String f(double v) => v.toStringAsFixed(1).padLeft(7);
    return '$label\n'
        '  frames ${frameCount.toString().padLeft(5)}   '
        'janky ${jankFrames.toString().padLeft(4)} '
        '(${jankPercent.toStringAsFixed(1)}%)   '
        'severe ${severeJankFrames.toString().padLeft(3)}\n'
        '  build  p50 ${f(percentile(buildMs, .50))}  '
        'p90 ${f(percentile(buildMs, .90))}  '
        'p99 ${f(percentile(buildMs, .99))}\n'
        '  raster p50 ${f(percentile(rasterMs, .50))}  '
        'p90 ${f(percentile(rasterMs, .90))}  '
        'p99 ${f(percentile(rasterMs, .99))}\n'
        '  total  p50 ${f(percentile(t, .50))}  '
        'p90 ${f(percentile(t, .90))}  '
        'p99 ${f(percentile(t, .99))}  '
        'max ${f(worstMs)}';
  }

  /// Compact one-line summary for a results table.
  String get row {
    final t = totalMs;
    String f(double v) => v.toStringAsFixed(1).padLeft(6);
    return '${label.padRight(26)}'
        '${frameCount.toString().padLeft(6)}'
        '${f(percentile(t, .50))}'
        '${f(percentile(t, .90))}'
        '${f(percentile(t, .99))}'
        '${f(worstMs)}'
        '${jankFrames.toString().padLeft(7)}'
        '${jankPercent.toStringAsFixed(0).padLeft(6)}%';
  }

  static String get tableHeader =>
      '${'scenario'.padRight(26)}${'frames'.padLeft(6)}'
      '${'p50'.padLeft(6)}${'p90'.padLeft(6)}${'p99'.padLeft(6)}'
      '${'max'.padLeft(6)}${'janky'.padLeft(7)}${'%'.padLeft(7)}';

  /// Largest single frame, useful for spotting a freeze.
  Duration get worst => _timings.isEmpty
      ? Duration.zero
      : _timings
          .map((t) => t.buildDuration + t.rasterDuration)
          .reduce((a, b) => a > b ? a : b);

  /// Mean frames per second implied by the captured frames.
  double get impliedFps {
    if (totalMs.isEmpty) return 0;
    final mean = totalMs.reduce((a, b) => a + b) / totalMs.length;
    return mean <= 0 ? 0 : math.min(60.0, 1000.0 / mean);
  }
}
