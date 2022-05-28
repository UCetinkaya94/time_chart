import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/constants.dart';
import '../view_mode.dart';
import '../translations/translations.dart';

abstract class ChartEngine extends CustomPainter {
  static const int toleranceDay = 1;

  ChartEngine({
    this.scrollController,
    int? dayCount,
    required this.viewMode,
    this.firstValueDateTime,
    required this.context,
    super.repaint,
  })  : dayCount = math.max(dayCount ?? -1, viewMode.dayCount),
        translations = Translations(context);

  final ScrollController? scrollController;
  final int dayCount;
  final ViewMode viewMode;
  final DateTime? firstValueDateTime;
  final BuildContext context;
  final Translations translations;

  int get currentDayFromScrollOffset {
    if (!scrollController!.hasClients) return 0;
    return (scrollController!.offset / blockWidth!).floor();
  }

  double get rightMargin => _rightMargin;
  double get barWidth => _barWidth;
  double get paddingForAlignedBar => _paddingForAlignedBar;
  double? get blockWidth => _blockWidth;

  TextTheme get textTheme => Theme.of(context).textTheme;

  double _rightMargin = 0.0;
  double _barWidth = 0.0;
  double _paddingForAlignedBar = 0.0;
  double? _blockWidth;

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

  void setDefaultValue(Size size) {
    setRightMargin();
    _blockWidth = size.width / dayCount;
    _barWidth = blockWidth! * kBarWidthRatio;
    // 바의 위치를 가운데로 정렬하기 위한 [padding]
    _paddingForAlignedBar = blockWidth! * kBarPaddingWidthRatio;
  }
}
