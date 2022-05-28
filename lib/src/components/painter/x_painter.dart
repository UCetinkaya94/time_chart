import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/translations/translations.dart';
import 'package:time_chart/src/components/view_mode.dart';

class XPainter extends CustomPainter {
  XPainter({
    required super.repaint,
    required this.viewMode,
    required this.context,
    required this.dayCount,
    required this.firstValueDateTime,
    required this.scrollController,
  }) : translations = Translations(context);

  final int dayCount;
  final ViewMode viewMode;
  final BuildContext context;
  final DateTime firstValueDateTime;
  final ScrollController scrollController;
  final Translations translations;

  double _paddingForAlignedBar = 0.0;
  late double _blockWidth;

  int get currentDayFromScrollOffset {
    if (!scrollController.hasClients) return 0;
    return (scrollController.offset / _blockWidth).floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _blockWidth = size.width / dayCount;
    _paddingForAlignedBar = _blockWidth * kBarPaddingWidthRatio;

    final weekday = getShortWeekdayList(context);
    final viewModeLimitDay = viewMode.dayCount;
    final dayFromScrollOffset = currentDayFromScrollOffset - toleranceDay;

    var currentDate =
        firstValueDateTime.subtract(Duration(days: dayFromScrollOffset));

    final maxCount = dayFromScrollOffset + viewModeLimitDay + toleranceDay * 2;

    for (int i = dayFromScrollOffset; i <= maxCount; i++) {
      late String text;
      bool isDashed = true;

      if (viewMode == ViewMode.weekly) {
        text = weekday[currentDate.weekday % 7];
        if (currentDate.weekday == DateTime.sunday) isDashed = false;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        text = currentDate.day.toString();
        currentDate = currentDate.subtract(const Duration(days: 1));
        // Monthly view mode displays the label once every 7 days.
        if (i % 7 != 6) {
          continue;
        }
      }

      final dx = size.width - (i + 1) * _blockWidth;

      _drawXText(canvas, size, text, dx);
      _drawVerticalDivideLine(canvas, size, dx, isDashed);
    }
  }

  void _drawXText(Canvas canvas, Size size, String text, double dx) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: Theme.of(context).textTheme.bodyText2!.copyWith(
              color: kTextColor,
            ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final dy = size.height - textPainter.height;

    if (viewMode == ViewMode.weekly) {
      final availableSpace = _blockWidth - 2 * kLineStrokeWidth;
      final textWidth = textPainter.width;
      final paddingLeft = (availableSpace / 2) - (textWidth / 2);

      textPainter.paint(canvas, Offset(dx + paddingLeft, dy));
    } else {
      textPainter.paint(canvas, Offset(dx + _paddingForAlignedBar, dy));
    }
  }

  void _drawVerticalDivideLine(
    Canvas canvas,
    Size size,
    double dx,
    bool isDashed,
  ) {
    Paint paint = Paint()
      ..color = kLineColor3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = kLineStrokeWidth;

    Path path = Path();
    path.moveTo(dx, 0);
    path.lineTo(dx, size.height);

    canvas.drawPath(
      isDashed
          ? dashPath(path,
              dashArray: CircularIntervalList<double>(<double>[2, 2]))
          : path,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant XPainter oldDelegate) {
    return true;
  }
}
