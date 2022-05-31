import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/painter/x_painter.dart';
import 'package:time_chart/src/components/utils/extensions.dart';
import 'package:touchable/touchable.dart';

import '../time_chart.dart';
import 'components/painter/y_painter.dart';
import 'components/painter/border_line_painter.dart';
import 'components/scroll/custom_scroll_physics.dart';
import 'components/scroll/my_single_child_scroll_view.dart';
import 'components/painter/bar_painter.dart';
import 'components/tooltip/tooltip_overlay.dart';
import 'components/tooltip/tooltip_size.dart';
import 'components/translations/translations.dart';
import 'components/utils/context_utils.dart';

/// The padding to prevent cut off the top of the chart.
const double kTimeChartTopPadding = 4.0;

class DurationChart extends StatefulWidget {
  const DurationChart({
    super.key,
    this.width,
    this.height = 280.0,
    required this.barColor,
    required this.rawData,
    this.timeChartSizeAnimationDuration = const Duration(milliseconds: 300),
    this.tooltipDuration = const Duration(seconds: 7),
    this.tooltipBackgroundColor,
    this.tooltipStart = "START",
    this.tooltipEnd = "END",
    this.activeTooltip = true,
    this.viewMode = ViewMode.weekly,
    this.defaultPivotHour = 0,
    required this.onRangeChange,
    required this.onTapOverlay,
    this.firstDayOfTheWeek = DateTime.monday,
  }) : assert(0 <= defaultPivotHour && defaultPivotHour < 24);

  /// Total chart width.
  ///
  /// Default is parent box width.
  final double? width;

  /// Total chart height
  ///
  /// Default is `280.0`. Actual height is [height] + 4.0([kTimeChartTopPadding]).
  final double height;

  /// The color of the bar in the chart.
  ///
  final Color barColor;

  /// Pair of a date and a duration.
  ///
  final Map<DateTime, Duration> rawData;

  /// The size animation duration of time chart when is changed pivot hours.
  ///
  /// Default value is `Duration(milliseconds: 300)`.
  final Duration timeChartSizeAnimationDuration;

  /// The Tooltip duration.
  ///
  /// Default is `Duration(seconds: 7)`.
  final Duration tooltipDuration;

  /// The color of the tooltip background.
  ///
  /// [Theme.of(context).dialogBackgroundColor] is default color.
  final Color? tooltipBackgroundColor;

  /// The label of [ChartType.time] tooltip.
  ///
  /// Default is "start"
  final String tooltipStart;

  /// The label of [ChartType.time] tooltip.
  ///
  /// Default is "end"
  final String tooltipEnd;

  /// If it's `true` active showing the tooltip when tapped a bar.
  ///
  /// Default value is `true`
  final bool activeTooltip;

  /// The chart view mode.
  ///
  /// There is two type [ViewMode.weekly] and [ViewMode.monthly].
  final ViewMode viewMode;

  /// The hour is used as a pivot if the data time range is fully visible or
  /// there is no data when the type is the [ChartType.time].
  ///
  /// For example, this value will be used when you use the data like below.
  /// ```dart
  /// [DateTimeRange(
  ///       start: DateTime(2021, 12, 17, 3, 12),
  ///       end: DateTime(2021, 12, 18, 2, 30),
  /// )];
  /// ```
  ///
  /// If there is no data when the type is the [ChartType.amount], 8 Hours is
  /// used as a top hour, not this value.
  ///
  /// It must be in the range of 0 to 23.
  final int defaultPivotHour;

  final void Function(DateTime leftDate, DateTime rightDate) onRangeChange;

  final void Function(DateTime date) onTapOverlay;

  final int firstDayOfTheWeek;

  @override
  DurationChartState createState() => DurationChartState();
}

class DurationChartState extends State<DurationChart>
    with TickerProviderStateMixin {
  static const Duration _tooltipFadeInDuration = Duration(milliseconds: 150);
  static const Duration _tooltipFadeOutDuration = Duration(milliseconds: 75);

  CustomScrollPhysics? _scrollPhysics;
  final _scrollControllerGroup = LinkedScrollControllerGroup();
  late final ScrollController _barController;
  late final ScrollController _xLabelController;
  late final AnimationController _sizeController;
  late final Animation<double> _sizeAnimation;

  Timer? _pivotHourUpdatingTimer;

  /// Used to display the tooltip
  OverlayEntry? _overlayEntry;

  /// Determines how long the tooltip is shown
  Timer? _tooltipHideTimer;

  Rect? _currentVisibleTooltipRect;

  /// Handles fade in out animations of tooltips
  late final AnimationController _tooltipController;

  /// The width of the bar and the its padding
  double? _totalBarWidth;

  /// The height of the entire chart at the start of the animation
  late double _animationBeginHeight = widget.height;

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0);

  double _previousScrollOffset = 0;

  late int _topHour = _getMaxHour();

  Offset? _overlayOffset;

  late SplayTreeMap<DateTime, Duration> sortedData = _sortData();

  late DateTime latestDate;

  late int barCount = widget.viewMode.dayCount;

  @override
  void initState() {
    super.initState();

    _barController = _scrollControllerGroup.addAndGet();
    _xLabelController = _scrollControllerGroup.addAndGet();

    _sizeController = AnimationController(
      duration: widget.timeChartSizeAnimationDuration,
      vsync: this,
    );

    _tooltipController = AnimationController(
      duration: _tooltipFadeInDuration,
      reverseDuration: _tooltipFadeOutDuration,
      vsync: this,
    );

    _sizeAnimation = CurvedAnimation(
      parent: _sizeController,
      curve: Curves.easeInOut,
    );

    // Listen to global pointer events so that we can hide a tooltip immediately
    // if some other control is clicked on.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);

    _addScrollNotifier();
  }

  @override
  void didUpdateWidget(covariant DurationChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rawData != widget.rawData) {
      sortedData = _sortData();
      _topHour = _getMaxHour();
    }
  }

  @override
  void dispose() {
    _removeEntry();
    _barController.dispose();
    _xLabelController.dispose();
    _sizeController.dispose();
    _tooltipController.dispose();
    _pivotHourUpdatingTimer?.cancel();
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  SplayTreeMap<DateTime, Duration> _sortData() {
    if (widget.rawData.isEmpty) {
      return SplayTreeMap<DateTime, Duration>();
    }

    final sorted = SplayTreeMap<DateTime, Duration>.from(
      widget.rawData,
      (a, b) => b.compareTo(a),
    );

    latestDate = sorted.firstKey() ?? DateTime.now();

    switch (widget.viewMode) {
      case ViewMode.weekly:
        final lastDayOfWeek =
            latestDate.lastDateOfWeek(widget.firstDayOfTheWeek);
        if (latestDate.isBeforeDate(lastDayOfWeek)) {
          latestDate = lastDayOfWeek;
          sorted[latestDate] = Duration.zero;
        }
        break;
      case ViewMode.monthly:
        final lastDayOfMonth = latestDate.lastDayOfMonth;
        if (latestDate.isBeforeDate(lastDayOfMonth)) {
          latestDate = lastDayOfMonth;
          sorted[latestDate] = Duration.zero;
        }
        break;
      case ViewMode.yearly:
        if (latestDate.month < DateTime.december) {
          latestDate = DateTime(latestDate.year, DateTime.december);
          sorted[latestDate] = Duration.zero;
        }
        break;
    }

    final end = sorted.lastKey();
    final start = sorted.firstKey();

    if (start != null && end != null) {
      if (widget.viewMode == ViewMode.yearly) {
        barCount = end.differenceInMonths(start) + 1;
      } else {
        barCount = end.differenceInDays(start) + 1;
      }
    }

    if (barCount < widget.viewMode.dayCount) {
      barCount = widget.viewMode.dayCount;
    }

    return sorted;
  }

  void _addScrollNotifier() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final minDifference = _totalBarWidth!;

      _scrollControllerGroup.addOffsetChangedListener(() {
        final difference =
            (_scrollControllerGroup.offset - _previousScrollOffset).abs();

        if (difference >= minDifference) {
          _scrollOffsetNotifier.value = _scrollControllerGroup.offset;
          _previousScrollOffset = _scrollControllerGroup.offset;
        }
      });
    });
  }

  void _handlePointerEvent(PointerEvent event) {
    if (_overlayEntry == null) return;
    if (_overlayOffset == null) return;

    if (event is PointerDownEvent) {
      final eventOffset = event.position;

      final rect = Rect.fromPoints(
          Offset(_overlayOffset!.dx, _overlayOffset!.dy),
          Offset(
            _overlayOffset!.dx + kAmountTooltipSize.width,
            _overlayOffset!.dy + kAmountTooltipSize.height,
          ));

      // Don't remove the entry if we touched it
      if (rect.contains(eventOffset)) {
        return;
      }

      _removeEntry();
    }
  }

  /// When the relevant bar is pressed, a tooltip is displayed.
  ///
  /// The location is the distance from the left in the x-axis
  /// and the top in the y-axis.
  ///
  /// This callback is used to manage the overlay entry.
  void _tooltipCallback({
    required double amount,
    required DateTime amountDate,
    required Rect rect,
    required ScrollPosition position,
    required double barWidth,
  }) {
    if (!widget.activeTooltip) return;

    // Tooltips on bars outside the range of the currently visible chart are ignored
    final viewRange = _totalBarWidth! * widget.viewMode.dayCount;
    final actualPosition = position.maxScrollExtent - position.pixels;
    if (rect.left < actualPosition || actualPosition + viewRange < rect.left) {
      return;
    }

    // If the currently visible tooltip is called again, it is ignored.
    if ((_tooltipHideTimer?.isActive ?? false) &&
        _currentVisibleTooltipRect == rect) return;
    _currentVisibleTooltipRect = rect;

    HapticFeedback.lightImpact();
    _removeEntry();

    _tooltipController.forward();
    _overlayEntry = OverlayEntry(
      builder: (_) => _buildOverlay(
        rect,
        position,
        barWidth,
        amount: amount,
        amountDate: amountDate,
      ),
    );
    Overlay.of(context)!.insert(_overlayEntry!);
    _tooltipHideTimer = Timer(widget.tooltipDuration, _removeEntry);
  }

  double get _tooltipPadding => kTooltipArrowWidth + 2.0;

  Widget _buildOverlay(
    Rect rect,
    ScrollPosition position,
    double barWidth, {
    required double amount,
    required DateTime amountDate,
  }) {
    // Get the current widget's position
    final widgetOffset = context.getRenderBoxOffset()!;
    const tooltipSize = kAmountTooltipSize;

    final candidateTop = rect.top +
        widgetOffset.dy -
        tooltipSize.height / 2 +
        kTimeChartTopPadding +
        kTooltipArrowHeight / 2;

    final scrollPixels = position.maxScrollExtent - position.pixels;
    final localLeft = rect.left + widgetOffset.dx - scrollPixels;
    final tooltipTop = max(candidateTop, 0.0);

    Direction direction = Direction.left;
    double tooltipLeft = localLeft - tooltipSize.width - _tooltipPadding;
    // Check if the tooltip needs to be placed to the right of the bar
    if (tooltipLeft < widgetOffset.dx) {
      direction = Direction.right;
      tooltipLeft = localLeft + barWidth + _tooltipPadding;
    }

    _overlayOffset = Offset(tooltipLeft, tooltipTop);

    return Positioned(
      top: tooltipTop,
      left: tooltipLeft,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _tooltipController,
          curve: Curves.fastOutSlowIn,
        ),
        child: GestureDetector(
          onTap: () {
            widget.onTapOverlay(amountDate);
          },
          child: TooltipOverlay(
            backgroundColor: Colors.black,
            textColor: Colors.white,
            amountHour: amount,
            amountDate: amountDate,
            direction: direction,
            start: widget.tooltipStart,
            end: widget.tooltipEnd,
          ),
        ),
      ),
    );
  }

  /// Removes the currently existing tooltip
  void _removeEntry() {
    _tooltipHideTimer?.cancel();
    _tooltipHideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getRightMargin(BuildContext context) {
    final translations = Translations(context);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: translations.formatHourOnly(12),
        style: Theme.of(context)
            .textTheme
            .bodyText2!
            .copyWith(color: Colors.white38),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp.width + kYLabelMargin;
  }

  void _handlePanDown(_) {
    _scrollPhysics!.setPanDownPixels(_barController.position.pixels);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _pivotHourUpdatingTimer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _pivotHourUpdatingTimer = Timer(
        const Duration(milliseconds: 100),
        _timerCallback,
      );
    }
    return true;
  }

  void _timerCallback() {
    final currentMax = _getMaxHour();
    final prevMax = _topHour;

    _runAmountHeightAnimation(prevMax, currentMax);
    _topHour = currentMax;
  }

  int _getMaxHour() {
    final double rightIndex;

    if (sortedData.isEmpty) {
      return 8;
    }

    if (!_barController.hasClients) {
      rightIndex = 0.0;
    } else {
      rightIndex = getRightMostVisibleIndex(
        _barController.position,
        _totalBarWidth!,
      );
    }

    final startDate = dateForIndex(
      latestDate: latestDate,
      index: rightIndex.truncate() + widget.viewMode.dayCount - 1,
      viewMode: widget.viewMode,
    );

    final endDate = dateForIndex(
      index: rightIndex.truncate(),
      latestDate: latestDate,
      viewMode: widget.viewMode,
    );

    if (_barController.hasClients) {
      widget.onRangeChange(startDate, endDate);
    }

    final visibleItems = <Duration>{};

    var date = endDate;

    while (date.isSameDateOrAfter(startDate)) {
      visibleItems.add(sortedData.valueForDate(date, widget.viewMode));

      if (widget.viewMode == ViewMode.yearly) {
        date = date.subtractMonths(1);
      } else {
        date = date.subtractDays(1);
      }
    }

    double currentMax = 0;

    for (final item in visibleItems) {
      final hours = item.inMinutes / 60;

      if (hours > currentMax) {
        currentMax = hours;
      }
    }

    if (currentMax < 10) {
      return _roundTo(currentMax.truncate() + 1, 2);
    }

    if (currentMax.truncate() + 1 < 100) {
      return _roundTo(currentMax.truncate() + 1, 20);
    }

    return _roundTo(currentMax.truncate() + 1, 50);
  }

  int _roundTo(int number, int divider) {
    return (number / divider).ceil() * divider;
  }

  double get heightWithoutLabel => widget.height - kXLabelHeight;

  void _runAmountHeightAnimation(int prevTopHour, int currentTopHour) {
    if (prevTopHour == currentTopHour) return;

    final prevDif = prevTopHour.toDouble();
    final currentDiff = currentTopHour.toDouble();

    setState(() {
      _animationBeginHeight =
          (currentDiff / prevDif) * heightWithoutLabel + kXLabelHeight;
    });
    _sizeController.reverse(from: 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = widget.width ?? constraints.maxWidth;
        final viewModeLimitDay = widget.viewMode.dayCount;
        final key = ValueKey(_topHour * 100);

        final yLabelWidth = _getRightMargin(context);
        final totalWidth = widget.width ?? constraints.maxWidth;

        _totalBarWidth ??= (totalWidth - yLabelWidth) / viewModeLimitDay;

        final innerSize = Size(
          _totalBarWidth! * max(barCount, viewModeLimitDay),
          double.infinity,
        );

        if (_shouldSetPhysics()) {
          _scrollPhysics = CustomScrollPhysics(
            blockWidth: _totalBarWidth!,
            viewMode: widget.viewMode,
            scrollPhysicsState: ScrollPhysicsState(
              barCount: barCount,
            ),
          );
        }

        return SizedBox(
          height: widget.height + kTimeChartTopPadding,
          width: actualWidth,
          child: ClipRRect(
            child: GestureDetector(
              onPanDown: _handlePanDown,
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  _buildAnimatedBox(
                    topPadding: kTimeChartTopPadding,
                    width: totalWidth,
                    alignment: Alignment.topCenter,
                    child: CustomPaint(
                      key: key,
                      size: Size(totalWidth, double.infinity),
                      painter: YPainter(
                        context: context,
                        viewMode: widget.viewMode,
                        topHour: _topHour,
                      ),
                    ),
                  ),
                  _buildBorder(
                    totalWidth,
                    yLabelWidth,
                    key,
                    innerSize,
                    context,
                  ),
                  _buildBars(totalWidth, yLabelWidth, key, innerSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldSetPhysics() {
    if (_scrollPhysics == null) return true;
    if (_scrollPhysics!.viewMode != widget.viewMode) return true;
    return _scrollPhysics!.scrollPhysicsState.barCount != barCount;
  }

  Positioned _buildBars(
    double totalWidth,
    double yLabelWidth,
    ValueKey<int> key,
    Size innerSize,
  ) {
    return Positioned(
      top: kTimeChartTopPadding,
      child: Stack(
        children: [
          SizedBox(
            width: totalWidth - yLabelWidth,
            height: widget.height - kXLabelHeight,
          ),
          _buildAnimatedBox(
            bottomPadding: kXLabelHeight,
            width: totalWidth - yLabelWidth,
            alignment: Alignment.bottomCenter,
            child: _buildHorizontalScrollView(
              key: key,
              controller: _barController,
              child: CanvasTouchDetector(
                gesturesToOverride: const [
                  GestureType.onTapUp,
                  GestureType.onLongPressStart,
                  GestureType.onLongPressMoveUpdate,
                ],
                builder: (context) {
                  return CustomPaint(
                    size: innerSize,
                    painter: BarPainter(
                      scrollController: _barController,
                      latestDate: latestDate,
                      repaint: _scrollOffsetNotifier,
                      context: context,
                      sortedData: sortedData,
                      barColor: widget.barColor,
                      topHour: _topHour,
                      tooltipCallback: _tooltipCallback,
                      dayCount: barCount,
                      viewMode: widget.viewMode,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Positioned _buildBorder(
    double totalWidth,
    double yLabelWidth,
    ValueKey<int> key,
    Size innerSize,
    BuildContext context,
  ) {
    return Positioned(
      top: kTimeChartTopPadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: totalWidth - yLabelWidth,
            height: widget.height,
          ),
          const Positioned.fill(
            child: CustomPaint(painter: BorderLinePainter()),
          ),
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: _buildHorizontalScrollView(
                key: key,
                controller: _xLabelController,
                child: CustomPaint(
                  size: innerSize,
                  painter: XPainter(
                    scrollController: _xLabelController,
                    latestDate: latestDate,
                    data: sortedData,
                    repaint: _scrollOffsetNotifier,
                    context: context,
                    viewMode: widget.viewMode,
                    barCount: barCount,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalScrollView({
    required Widget child,
    required Key key,
    required ScrollController? controller,
  }) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (OverscrollIndicatorNotification overScroll) {
        overScroll.disallowIndicator();
        return false;
      },
      child: MySingleChildScrollView(
        reverse: true,
        scrollDirection: Axis.horizontal,
        controller: controller,
        physics: _scrollPhysics,
        child: RepaintBoundary(
          key: key,
          child: child,
        ),
      ),
    );
  }

  Widget _buildAnimatedBox({
    required Widget child,
    required double width,
    double topPadding = 0.0,
    double bottomPadding = 0.0,
    required Alignment alignment,
  }) {
    final heightAnimation = Tween<double>(
      begin: widget.height,
      end: _animationBeginHeight,
    ).animate(_sizeAnimation);

    return AnimatedBuilder(
      animation: _sizeAnimation,
      builder: (context, child) {
        return Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            height: heightAnimation.value - bottomPadding,
            width: width,
            alignment: alignment,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

extension on SplayTreeMap<DateTime, Duration> {
  Duration valueForDate(DateTime date, ViewMode viewMode) {
    if (this[date] != null) {
      return this[date]!;
    }

    final key1 = lastKeyBefore(date);
    final key2 = firstKeyAfter(date);

    if (viewMode == ViewMode.yearly) {
      final res1 = _checkMonth(key1, date);
      final res2 = _checkMonth(key2, date);

      if (res1 != null) return res1;
      if (res2 != null) return res2;
    }

    final res1 = _checkDate(key1, date);
    final res2 = _checkDate(key2, date);

    if (res1 != null) return res1;
    if (res2 != null) return res2;

    return Duration.zero;
  }

  Duration? _checkDate(DateTime? key, DateTime date) {
    if (key != null && key.isSameDate(date)) {
      final value = this[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Duration? _checkMonth(DateTime? key, DateTime date) {
    if (key != null && key.year == date.year && key.month == date.month) {
      final value = this[key];
      if (value != null) {
        return value;
      }
    }
    return null;
  }
}
