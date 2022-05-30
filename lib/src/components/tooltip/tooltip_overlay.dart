import 'package:flutter/material.dart';

import 'tooltip_shape_border.dart';
import 'tooltip_size.dart';
import '../translations/translations.dart';

const double kTooltipArrowWidth = 8.0;
const double kTooltipArrowHeight = 16.0;

enum Direction { left, right }

@immutable
class TooltipOverlay extends StatelessWidget {
  const TooltipOverlay({
    Key? key,
    required this.amountHour,
    required this.amountDate,
    required this.direction,
    required this.textColor,
    required this.backgroundColor,
    required this.start,
    required this.end,
  }) : super(key: key);

  final double amountHour;
  final DateTime amountDate;
  final Direction direction;
  final Color backgroundColor;
  final Color textColor;
  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final child = _AmountTooltipOverlay(
      textColor: textColor,
      durationHour: amountHour,
      durationDate: amountDate,
    );

    return Material(
      color: const Color(0x00ffffff),
      child: Container(
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: TooltipShapeBorder(direction: direction),
          shadows: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4.0,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

@immutable
class _AmountTooltipOverlay extends StatelessWidget {
  const _AmountTooltipOverlay({
    Key? key,
    required this.textColor,
    required this.durationHour,
    required this.durationDate,
  }) : super(key: key);

  final double durationHour;
  final DateTime durationDate;
  final Color textColor;

  int _ceilMinutes() {
    double decimal = durationHour - durationHour.toInt();
    return (decimal * 60 + 0.01).toInt() == 60 ? 1 : 0;
  }

  String _getMinute() {
    double decimal = durationHour - durationHour.toInt();
    // 3.99와 같은 무한소수를 고려한다.
    int minutes = (decimal * 60 + 0.01).toInt() % 60;
    return minutes > 0 ? '$minutes' : '';
  }

  String _getHour() {
    final hour = durationHour.toInt() + _ceilMinutes();
    return hour > 0 ? '$hour' : '';
  }

  Widget _buildContent(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final translations = Translations(context);
    final textTheme = Theme.of(context).textTheme;
    final body2 = textTheme.bodyText2!;
    final bodyTextStyle = body2.copyWith(
      color: textColor,
      height: 1.2,
    );
    final sub1 = textTheme.subtitle1!;
    final subTitleStyle = sub1.copyWith(
      color: textColor,
      height: 1.2,
    );
    final headerStyle = textTheme.headline4!.copyWith(height: 1.2, color: textColor);

    final hourString = _getHour();
    final minuteString = _getMinute();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hourString.isNotEmpty)
                Text(
                  _getHour(),
                  style: headerStyle,
                  textScaleFactor: 1.0,
                ),
              if (hourString.isNotEmpty)
                Text(
                  '${translations.shortHour} ',
                  style: subTitleStyle,
                  textScaleFactor: 1.0,
                ),
              if (minuteString.isNotEmpty)
                Text(
                  _getMinute(),
                  style: headerStyle,
                  textScaleFactor: 1.0,
                ),
              if (minuteString.isNotEmpty)
                Text(
                  translations.shortMinute,
                  style: subTitleStyle,
                  textScaleFactor: 1.0,
                ),
            ],
          ),
          Text(
            localizations.formatShortMonthDay(durationDate),
            style: bodyTextStyle,
            textScaleFactor: 1.0,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const size = kAmountTooltipSize;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildContent(context),
      ),
    );
  }
}
