import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/scroll/custom_scroll_physics.dart';
import 'package:time_chart/src/components/translations/translations.dart';
import 'package:time_chart/src/components/utils/extensions.dart';
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
    required this.sortedData,
    required this.topHour,
    required this.tooltipCallback,
    required this.barColor,
  })  : dayCount = max(dayCount ?? -1, viewMode.dayCount),
        translations = Translations(context);

  final int dayCount;
  final ViewMode viewMode;
  final BuildContext context;
  final Translations translations;
  final ScrollController scrollController;
  final TooltipCallback tooltipCallback;
  final Color barColor;
  final SplayTreeMap<DateTime, Duration> sortedData;
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
      ..color = barColor
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
    _blockWidth = size.width / dayCount;
    _barWidth = _blockWidth! * kBarWidthRatio;
    // [padding] to center the bar position
    _paddingForAlignedBar = _blockWidth! * kBarPaddingWidthRatio;

    final List<AmountBarItem> coordinates = [];

    if (sortedData.isEmpty) return [];

    final intervalOfBars = _blockWidth!;
    final startIndex = currentDayFromScrollOffset - 1;
    final endIndex = startIndex + viewMode.dayCount + 2;

    for (int index = startIndex; index <= endIndex; index++) {
      final date = dateForIndex(
        index: index,
        sortedData: sortedData,
        viewMode: viewMode,
      );

      final barPosition = index + 1;

      final amountSum = _amountForDate(date);
      final normalizedTop = max(0, amountSum) / topHour;
      final dy = size.height - normalizedTop * size.height;
      final dx = size.width - intervalOfBars * barPosition;

      coordinates.add(AmountBarItem(dx, dy, amountSum, date));
    }

    return coordinates;
  }

  double _amountForDate(DateTime date) {
    if (sortedData.containsKey(date)) {
      return sortedData[date]!.inMinutes / 60;
    }

    final before = sortedData.lastKeyBefore(date);
    final after = sortedData.firstKeyAfter(date);

    DateTime? key;

    if (before != null && before.isSameDate(date)) {
      key = before;
    } else if (after != null && after.isSameDate(date)) {
      key = after;
    }

    if (key != null) {
      return sortedData[key]!.inMinutes / 60;
    }

    return 0.0;
  }

  @override
  bool shouldRepaint(BarPainter oldDelegate) {
    return oldDelegate.sortedData != sortedData;
  }
}

class AmountBarItem {
  final double dx;
  final double dy;
  final double amount;
  final DateTime dateTime;

  AmountBarItem(this.dx, this.dy, this.amount, this.dateTime);
}
