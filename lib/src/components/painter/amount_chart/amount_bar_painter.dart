import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/painter/bar_painter.dart';
import 'package:touchable/touchable.dart';
import '../chart_engine.dart';

class AmountBarPainter extends BarPainter<AmountBarItem> {
  AmountBarPainter({
    required super.scrollController,
    required super.repaint,
    required super.tooltipCallback,
    required super.context,
    required super.dataMap,
    required super.topHour,
    required super.bottomHour,
    required super.dayCount,
    required super.viewMode,
    super.barColor,
  });

  @override
  void drawBar(Canvas canvas, Size size, List<AmountBarItem> coordinates) {
    final touchyCanvas = TouchyCanvas(
      context,
      canvas,
      scrollController: scrollController,
      scrollDirection: AxisDirection.left,
    );

    final paint = Paint()
      ..color = barColor ?? Theme.of(context).colorScheme.secondary
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int index = 0; index < coordinates.length; index++) {
      final offsetWithAmount = coordinates[index];

      final left = paddingForAlignedBar + offsetWithAmount.dx;
      final right = paddingForAlignedBar + offsetWithAmount.dx + barWidth;
      final top = offsetWithAmount.dy;
      final bottom = size.height;

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTRB(left, top, right, bottom),
        topLeft: barRadius,
        topRight: barRadius,
      );

      callback(_) {
        tooltipCallback(
          amount: offsetWithAmount.amount,
          amountDate: offsetWithAmount.dateTime,
          position: scrollController!.position,
          rect: rRect.outerRect,
          barWidth: barWidth,
        );
      }

      touchyCanvas.drawRRect(
        rRect,
        paint,
        onTapUp: callback,
        onLongPressStart: callback,
        onLongPressMoveUpdate: callback,
      );
    }
  }

  @override
  List<AmountBarItem> generateCoordinates(Size size) {
    final List<AmountBarItem> coordinates = [];

    if (dataMap.isEmpty) return [];

    final intervalOfBars = size.width / dayCount;

    final viewLimitDay = viewMode.dayCount;
    final dayFromScrollOffset = currentDayFromScrollOffset;

    double amountSum = 0;
    int index = 0;

    for (final entry in dataMap.entries) {
      final int barPosition = 1 + index;

      if (barPosition - dayFromScrollOffset >
          viewLimitDay + ChartEngine.toleranceDay * 2) break;

      amountSum += entry.value.inMinutes / 60;

      final normalizedTop = max(0, amountSum - bottomHour) / topHour;

      final dy = size.height - normalizedTop * size.height;
      final dx = size.width - intervalOfBars * barPosition;

      coordinates.add(AmountBarItem(dx, dy, amountSum, entry.key));

      amountSum = 0;
      index++;
    }

    return coordinates;
  }
}

class AmountBarItem {
  final double dx;
  final double dy;
  final double amount;
  final DateTime dateTime;

  AmountBarItem(this.dx, this.dy, this.amount, this.dateTime);
}
