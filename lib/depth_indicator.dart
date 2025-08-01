import 'package:flutter/material.dart';

class DepthIndicator extends StatelessWidget {
  final int depth;
  final double indentWidth;
  final bool isLastChild;

  const DepthIndicator({
    Key? key,
    required this.depth,
    this.indentWidth = 10.0,
    required this.isLastChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: depth * indentWidth,
      child: CustomPaint(
        painter: _DepthPainter(depth, indentWidth, isLastChild),
      ),
    );
  }
}

class _DepthPainter extends CustomPainter {
  final int depth;
  final double indentWidth;
  final bool isLastChild;

  _DepthPainter(this.depth, this.indentWidth, this.isLastChild);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    for (int i = 1; i < depth; i++) {
      final dx = i * indentWidth;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }

    final dx = (depth - 1) * indentWidth;
    canvas.drawLine(Offset(dx, size.height / 2), Offset(dx + indentWidth, size.height / 2), paint);
    if (isLastChild) {
      canvas.drawLine(Offset(dx, size.height / 2), Offset(dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
