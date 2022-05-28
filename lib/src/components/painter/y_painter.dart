import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/translations/translations.dart';
import 'package:time_chart/src/components/view_mode.dart';

class YPainter extends CustomPainter {
  YPainter({
    super.repaint,
    int? dayCount,
    required this.viewMode,
    required this.context,
    required this.topHour,
    required this.bottomHour,
  })  : dayCount = max(dayCount ?? -1, viewMode.dayCount),
        translations = Translations(context);

  final int dayCount;
  final int topHour;
  final int bottomHour;
  final ViewMode viewMode;
  final BuildContext context;
  final Translations translations;

  double _rightMargin = 0.0;
  TextTheme get textTheme => Theme.of(context).textTheme;

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
        size.width - _rightMargin + kYLabelMargin,
        y - textTheme.bodyText2!.fontSize! / 2,
      ),
    );
  }

  void drawHorizontalLine(Canvas canvas, Size size, double dy) {
    Paint paint = Paint()
      ..color = kLineColor1
      ..strokeCap = StrokeCap.round
      ..strokeWidth = kLineStrokeWidth;

    canvas.drawLine(
      Offset(0, dy),
      Offset(size.width - _rightMargin, dy),
      paint,
    );
  }

  void setRightMargin() {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: translations.formatHourOnly(kPivotYLabelHour),
        style: textTheme.bodyText2!.copyWith(color: kTextColor),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    _rightMargin = tp.width + kYLabelMargin;
  }

  @override
  bool shouldRepaint(covariant YPainter oldDelegate) {
    return oldDelegate.topHour != topHour ||
        oldDelegate.bottomHour != bottomHour;
  }
}
