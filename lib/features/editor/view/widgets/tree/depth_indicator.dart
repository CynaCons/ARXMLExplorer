import 'package:flutter/material.dart';

class DepthIndicator extends StatelessWidget {
  final int depth;
  final double indentWidth;
  final bool isLastChild; // reserved for future tree drawing enhancements

  const DepthIndicator({
    super.key,
    required this.depth,
    this.indentWidth = 10.0,
    required this.isLastChild,
  });

  @override
  Widget build(BuildContext context) {
    // Depth 0 and 1 draw nothing, so skip the CustomPaint layer entirely —
    // at tens of thousands of rows the empty painters were pure overhead.
    if (depth <= 1) return SizedBox(width: depth * indentWidth);
    return SizedBox(
      width: depth * indentWidth,
      child: CustomPaint(
        painter: _DepthPainter(depth, indentWidth),
      ),
    );
  }
}

class _DepthPainter extends CustomPainter {
  final int depth;
  final double indentWidth;

  // Shared: a Paint per row per repaint is wasteful and the style is constant.
  static final Paint _linePaint = Paint()
    ..color = Colors.grey.withOpacity(0.45)
    ..strokeWidth = 1.0;

  const _DepthPainter(this.depth, this.indentWidth);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 1; i < depth; i++) {
      final dx = i * indentWidth;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), _linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DepthPainter oldDelegate) =>
      oldDelegate.depth != depth || oldDelegate.indentWidth != indentWidth;
}
