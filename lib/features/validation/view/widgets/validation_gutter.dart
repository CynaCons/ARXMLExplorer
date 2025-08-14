import 'package:flutter/material.dart';
import 'package:arxml_explorer/core/validation/issues.dart';

/// ValidationGutter displays aggregate issue markers aligned roughly to
/// vertical positions of issues (heuristic based on path depth).
class ValidationGutter extends StatelessWidget {
  final List<ValidationIssue> issues;
  const ValidationGutter({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      if (height <= 0) return const SizedBox.shrink();
      final buckets = <double, List<ValidationIssue>>{};
      for (final i in issues) {
        final segs = i.path.split('/').where((e) => e.isNotEmpty).length;
        final y = (segs * 13) % height;
        buckets.putIfAbsent(y, () => []).add(i);
      }
      return CustomPaint(painter: _GutterPainter(buckets));
    });
  }
}

class _GutterPainter extends CustomPainter {
  final Map<double, List<ValidationIssue>> buckets;
  _GutterPainter(this.buckets);

  Color _colorFor(ValidationSeverity s) {
    switch (s) {
      case ValidationSeverity.error:
        return Colors.redAccent;
      case ValidationSeverity.warning:
        return Colors.amber;
      case ValidationSeverity.info:
        return Colors.blueAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final w = size.width;
    buckets.forEach((y, list) {
      ValidationSeverity sev = ValidationSeverity.info;
      for (final i in list) {
        if (i.severity == ValidationSeverity.error) {
          sev = ValidationSeverity.error;
          break;
        }
        if (i.severity == ValidationSeverity.warning) {
          sev = ValidationSeverity.warning;
        }
      }
      paint
        ..color = _colorFor(sev)
        ..strokeWidth = (1.5 + (list.length - 1) * 0.6).clamp(1.5, 6.0);
      final dy = y.clamp(0.0, size.height - 1.0);
      canvas.drawLine(Offset(0, dy), Offset(w, dy), paint);
    });
  }

  @override
  bool shouldRepaint(covariant _GutterPainter old) => old.buckets != buckets;
}
