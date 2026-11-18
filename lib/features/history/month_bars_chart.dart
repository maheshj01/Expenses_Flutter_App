import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class MonthBar {
  const MonthBar({required this.lived, required this.invested, required this.earned});

  final int lived;
  final int invested;
  final int earned;
}

/// Twelve months of lived / invested bars with an earned line on top.
class MonthBarsChart extends StatelessWidget {
  const MonthBarsChart({super.key, required this.months, this.onMonthTap, this.height = 170});

  /// Exactly 12 values, January first.
  final List<MonthBar> months;
  final ValueChanged<int>? onMonthTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapUp: onMonthTap == null
            ? null
            : (d) {
                final i = (d.localPosition.dx / (constraints.maxWidth / 12)).floor();
                onMonthTap!(i.clamp(0, 11) + 1);
              },
        child: CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _Painter(months, context.colors),
        ),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.months, this.colors);

  final List<MonthBar> months;
  final AppColors colors;

  static const _labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  void paint(Canvas canvas, Size size) {
    const labelSpace = 18.0;
    final chartH = size.height - labelSpace;
    final maxValue = months.fold<int>(
      1,
      (m, b) => math.max(m, math.max(b.earned, math.max(b.lived, b.invested))),
    );
    final slot = size.width / 12;
    final barW = math.min(9.0, slot / 3.2);

    final grid = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = chartH - chartH * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    double y(int v) => chartH - (math.max(v, 0) / maxValue) * (chartH - 6);

    final lived = Paint()..color = colors.lived;
    final invested = Paint()..color = colors.invested;
    final earnedPath = Path();
    var started = false;

    for (var i = 0; i < 12; i++) {
      final b = months[i];
      final cx = slot * i + slot / 2;
      if (b.lived > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(cx - barW - 1, y(b.lived), cx - 1, chartH, const Radius.circular(2.5)),
          lived,
        );
      }
      if (b.invested > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(cx + 1, y(b.invested), cx + barW + 1, chartH, const Radius.circular(2.5)),
          invested,
        );
      }
      if (b.earned > 0) {
        started ? earnedPath.lineTo(cx, y(b.earned)) : earnedPath.moveTo(cx, y(b.earned));
        started = true;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(fontSize: 10, color: colors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - tp.height));
    }

    canvas.drawPath(
      earnedPath,
      Paint()
        ..color = colors.earned
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Painter old) => old.months != months || old.colors != colors;
}
