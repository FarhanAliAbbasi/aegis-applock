import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PatternPadView extends StatefulWidget {
  final ValueChanged<String> onPatternEntered;
  final bool isError;
  final bool isEnabled;

  const PatternPadView({
    super.key,
    required this.onPatternEntered,
    this.isError = false,
    this.isEnabled = true,
  });

  @override
  State<PatternPadView> createState() => _PatternPadViewState();
}

class _PatternPadViewState extends State<PatternPadView> {
  final List<int> _selectedDots = [];
  Offset? _currentTouch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final sideLength = size > 0 ? size : 280.0;

        return Center(
          child: SizedBox(
            width: sideLength,
            height: sideLength,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _handlePanStart(details.localPosition, sideLength),
              onPanUpdate: (details) => _handlePanUpdate(details.localPosition, sideLength),
              onPanEnd: (_) => _handlePanEnd(),
              onPanCancel: () => _handlePanEnd(),
              child: CustomPaint(
                painter: _PatternPainter(
                  selectedDots: _selectedDots,
                  currentTouch: _currentTouch,
                  isError: widget.isError,
                  accentColor: widget.isError ? AppTheme.accentRed : AppTheme.primaryCyan,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePanStart(Offset position, double sideLength) {
    if (!widget.isEnabled) return;
    setState(() {
      _selectedDots.clear();
      _currentTouch = position;
    });
    _checkDotHit(position, sideLength);
  }

  void _handlePanUpdate(Offset position, double sideLength) {
    if (!widget.isEnabled) return;
    setState(() {
      _currentTouch = position;
    });
    _checkDotHit(position, sideLength);
  }

  void _handlePanEnd() {
    if (!widget.isEnabled) return;
    setState(() {
      _currentTouch = null;
    });
    if (_selectedDots.isNotEmpty) {
      widget.onPatternEntered(_selectedDots.join('-'));
    }
  }

  void _checkDotHit(Offset pos, double sideLength) {
    final cellSize = sideLength / 3;
    final hitRadius = cellSize * 0.45;

    for (int i = 0; i < 9; i++) {
      final row = i ~/ 3;
      final col = i % 3;
      final center = Offset(
        col * cellSize + cellSize / 2,
        row * cellSize + cellSize / 2,
      );

      if ((pos - center).distance <= hitRadius) {
        if (!_selectedDots.contains(i)) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedDots.add(i);
          });
        }
        break;
      }
    }
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> selectedDots;
  final Offset? currentTouch;
  final bool isError;
  final Color accentColor;

  _PatternPainter({
    required this.selectedDots,
    required this.currentTouch,
    required this.isError,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 3;

    // Draw connecting lines
    if (selectedDots.isNotEmpty) {
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.85)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final firstCenter = _getDotCenter(selectedDots[0], cellSize);
      path.moveTo(firstCenter.dx, firstCenter.dy);

      for (int i = 1; i < selectedDots.length; i++) {
        final nextCenter = _getDotCenter(selectedDots[i], cellSize);
        path.lineTo(nextCenter.dx, nextCenter.dy);
      }

      if (currentTouch != null) {
        path.lineTo(currentTouch!.dx, currentTouch!.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw 3x3 Dots
    for (int i = 0; i < 9; i++) {
      final center = _getDotCenter(i, cellSize);
      final isSelected = selectedDots.contains(i);

      if (isSelected) {
        // Outer glowing ring
        final ringPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 24, ringPaint);

        // Inner solid dot
        final dotPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 10, dotPaint);
      } else {
        // Unselected dot
        final dotPaint = Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 8, dotPaint);
      }
    }
  }

  Offset _getDotCenter(int index, double cellSize) {
    final row = index ~/ 3;
    final col = index % 3;
    return Offset(
      col * cellSize + cellSize / 2,
      row * cellSize + cellSize / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => true;
}
