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
  })  : dayCount = max(dayCount ?? -1, viewMode.dayCount),
        translations = Translations(context);

  final int dayCount;
  final int topHour;
  final ViewMode viewMode;
  final BuildContext context;
  final Translations translations;

  double _rightMargin = 0.0;
  TextTheme get textTheme => Theme.of(context).textTheme;

  @override
  void paint(Canvas canvas, Size size) {
    setRightMargin();

    final labelInterval = (size.height - kXLabelHeight) / topHour;

    final int timeStep;

    int divider = 2;

    // The top hour is always rounded up to the nearest multiplier of 2, 20 or 50 so
    // we will never run into a prime number which would cause an infinite loop here
    while (topHour % divider != 0) {
      divider++;
    }

    timeStep = (topHour / divider).truncate();

    double posY = 0;

    for (int time = topHour; time >= 0; time = time - timeStep) {
      drawYText(canvas, size, '$time h', posY);
      if (topHour > time && time > 0) {
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
    return oldDelegate.topHour != topHour;
  }
}
