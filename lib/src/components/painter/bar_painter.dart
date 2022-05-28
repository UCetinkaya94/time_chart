import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:touchable/touchable.dart';
import 'chart_engine.dart';

typedef TooltipCallback = void Function({
  required double amount,
  required DateTime amountDate,
  required Rect rect,
  required ScrollPosition position,
  required double barWidth,
});

class AmountBarPainter extends ChartEngine {
  AmountBarPainter({
    required super.scrollController,
    required super.repaint,
    required super.context,
    required super.dayCount,
    required super.viewMode,
    required this.dataMap,
    required this.topHour,
    required this.tooltipCallback,
    this.barColor,
  });

  final TooltipCallback tooltipCallback;
  final Color? barColor;
  final SplayTreeMap<DateTime, Duration> dataMap;
  final int topHour;
  final barRadius = const Radius.circular(6.0);

  @override
  void paint(Canvas canvas, Size size) {
    final coordinates = generateCoordinates(size);

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

  List<AmountBarItem> generateCoordinates(Size size) {
    setDefaultValue(size);
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

      final normalizedTop = max(0, amountSum) / topHour;

      final dy = size.height - normalizedTop * size.height;
      final dx = size.width - intervalOfBars * barPosition;

      coordinates.add(AmountBarItem(dx, dy, amountSum, entry.key));

      amountSum = 0;
      index++;
    }

    return coordinates;
  }

  @override
  bool shouldRepaint(AmountBarPainter oldDelegate) {
    return oldDelegate.dataMap != dataMap;
  }
}

class AmountBarItem {
  final double dx;
  final double dy;
  final double amount;
  final DateTime dateTime;

  AmountBarItem(this.dx, this.dy, this.amount, this.dateTime);
}
