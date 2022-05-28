import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/translations/translations.dart';
import 'package:time_chart/time_chart.dart';
import 'package:touchable/touchable.dart';

typedef TooltipCallback = void Function({
  required double amount,
  required DateTime amountDate,
  required Rect rect,
  required ScrollPosition position,
  required double barWidth,
});

class BarPainter extends CustomPainter {
  BarPainter({
    required this.scrollController,
    int? dayCount,
    required super.repaint,
    required this.context,
    required this.viewMode,
    required this.dataMap,
    required this.topHour,
    required this.tooltipCallback,
    this.barColor,
  })  : dayCount = max(dayCount ?? -1, viewMode.dayCount),
        translations = Translations(context);

  final int dayCount;
  final ViewMode viewMode;
  final BuildContext context;
  final Translations translations;
  final ScrollController scrollController;
  final TooltipCallback tooltipCallback;
  final Color? barColor;
  final SplayTreeMap<DateTime, Duration> dataMap;
  final int topHour;
  final barRadius = const Radius.circular(6.0);

  double _barWidth = 0.0;
  double _paddingForAlignedBar = 0.0;
  double? _blockWidth;

  int get currentDayFromScrollOffset {
    if (!scrollController.hasClients) return 0;
    return (scrollController.offset / _blockWidth!).floor();
  }

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

      final left = _paddingForAlignedBar + offsetWithAmount.dx;
      final right = _paddingForAlignedBar + offsetWithAmount.dx + _barWidth;
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
          position: scrollController.position,
          rect: rRect.outerRect,
          barWidth: _barWidth,
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

      if (barPosition - dayFromScrollOffset > viewLimitDay + toleranceDay * 2) {
        break;
      }
      
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

  void setDefaultValue(Size size) {
    _blockWidth = size.width / dayCount;
    _barWidth = _blockWidth! * kBarWidthRatio;
    // [padding] to center the bar position
    _paddingForAlignedBar = _blockWidth! * kBarPaddingWidthRatio;
  }

  @override
  bool shouldRepaint(BarPainter oldDelegate) {
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
