import 'package:flutter/material.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/painter/chart_engine.dart';

class YPainter extends ChartEngine {
  YPainter({
    required super.viewMode,
    required super.context,
    required this.topHour,
    required this.bottomHour,
  });

  final int topHour;
  final int bottomHour;

  @override
  void paint(Canvas canvas, Size size) {
    setRightMargin();

    final hourSuffix = translations.shortHour;
    final labelInterval =
        (size.height - kXLabelHeight) / (topHour - bottomHour);
    final hourDuration = topHour - bottomHour;

    final int timeStep;
    if (hourDuration >= 12) {
      timeStep = 4;
    } else if (hourDuration >= 8) {
      timeStep = 2;
    } else {
      timeStep = 1;
    }
    double posY = 0;

    for (int time = topHour; time >= bottomHour; time = time - timeStep) {
      drawYText(canvas, size, '$time $hourSuffix', posY);
      if (topHour > time && time > bottomHour) {
        drawHorizontalLine(canvas, size, posY);
      }

      posY += labelInterval * timeStep;
    }
  }

  void drawYText(Canvas canvas, Size size, String text, double y) {
    TextSpan span = TextSpan(
      text: text,
      style: textTheme.bodyText2!.copyWith(color: kTextColor),
    );

    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    tp.paint(
      canvas,
      Offset(
        size.width - rightMargin + kYLabelMargin,
        y - textTheme.bodyText2!.fontSize! / 2,
      ),
    );
  }

  void drawHorizontalLine(Canvas canvas, Size size, double dy) {
    Paint paint = Paint()
      ..color = kLineColor1
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kLineStrokeWidth;

    canvas.drawLine(Offset(0, dy), Offset(size.width - rightMargin, dy), paint);
  }

  @override
  bool shouldRepaint(covariant YPainter oldDelegate) {
    return oldDelegate.topHour != topHour ||
        oldDelegate.bottomHour != bottomHour;
  }
}
