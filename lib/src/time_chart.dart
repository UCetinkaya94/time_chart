import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:touchable/touchable.dart';

import '../time_chart.dart';
import 'components/painter/amount_chart/amount_x_label_painter.dart';
import 'components/painter/amount_chart/amount_y_label_painter.dart';
import 'components/painter/time_chart/time_x_label_painter.dart';
import 'components/painter/border_line_painter.dart';
import 'components/scroll/custom_scroll_physics.dart';
import 'components/scroll/my_single_child_scroll_view.dart';
import 'components/painter/chart_engine.dart';
import 'components/painter/time_chart/time_y_label_painter.dart';
import 'components/utils/time_assistant.dart';
import 'components/utils/time_data_processor.dart';
import 'components/painter/amount_chart/amount_bar_painter.dart';
import 'components/painter/time_chart/time_bar_painter.dart';
import 'components/tooltip/tooltip_overlay.dart';
import 'components/tooltip/tooltip_size.dart';
import 'components/translations/translations.dart';
import 'components/utils/context_utils.dart';

/// The padding to prevent cut off the top of the chart.
const double kTimeChartTopPadding = 4.0;

class TimeChart extends StatefulWidget {
  const TimeChart({
    super.key,
    this.chartType = ChartType.time,
    this.width,
    this.height = 280.0,
    this.barColor,
    required this.data,
    this.timeChartSizeAnimationDuration = const Duration(milliseconds: 300),
    this.tooltipDuration = const Duration(seconds: 7),
    this.tooltipBackgroundColor,
    this.tooltipStart = "START",
    this.tooltipEnd = "END",
    this.activeTooltip = true,
    this.viewMode = ViewMode.weekly,
    this.defaultPivotHour = 0,
  }) : assert(0 <= defaultPivotHour && defaultPivotHour < 24);

  /// The type of chart.
  ///
  /// Default is the [ChartType.time].
  final ChartType chartType;

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
  /// Default is the `Theme.of(context).colorScheme.secondary`.
  final Color? barColor;

  /// The list of [DateTimeRange].
  ///
  /// The first index is the latest data, The end data is the oldest data.
  /// It must be sorted because of correctly painting the chart.
  ///
  /// ```dart
  /// assert(data[0].isAfter(data[1])); // true
  /// ```
  final List<DateTimeRange> data;

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

  @override
  TimeChartState createState() => TimeChartState();
}

class TimeChartState extends State<TimeChart>
    with TickerProviderStateMixin, TimeDataProcessor {
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

  /// It is the sum of the width of the bar and the blank space on either side
  double? _blockWidth;

  /// The height of the entire chart at the start of the animation
  late double _animationBeginHeight = widget.height;

  /// A height value to start at the correct position at the start of the animation
  double? _heightForAlignTop;

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0);

  double _previousScrollOffset = 0;

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

    processData(widget, _getFirstItemDate());
  }

  @override
  void didUpdateWidget(covariant TimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
      processData(widget, _getFirstItemDate());
    }
  }

  @override
  void dispose() {
    _removeEntry();
    _barController.dispose();
    _xLabelController.dispose();
    _sizeController.dispose();
    _tooltipController.dispose();
    _cancelTimer();
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handlePointerEvent);
    super.dispose();
  }

  DateTime _getFirstItemDate({Duration addition = Duration.zero}) {
    return widget.data.isEmpty
        ? DateTime.now()
        : widget.data.first.end.dateWithoutTime().add(addition);
  }

  void _addScrollNotifier() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final minDifference = _blockWidth!;

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
    if (event is PointerDownEvent) _removeEntry();
  }

  /// When the relevant bar is pressed, a tooltip is displayed.
  ///
  /// The location is the distance from the left in the x-axis
  /// and the top in the y-axis.
  ///
  /// This callback is used to manage the overlay entry.
  void _tooltipCallback({
    DateTimeRange? range,
    double? amount,
    DateTime? amountDate,
    required Rect rect,
    required ScrollPosition position,
    required double barWidth,
  }) {
    assert(range != null || amount != null);

    if (!widget.activeTooltip) return;

    // Tooltips on bars outside the range of the currently visible chart are ignored
    final viewRange = _blockWidth! * widget.viewMode.dayCount;
    final actualPosition = position.maxScrollExtent - position.pixels;
    if (rect.left < actualPosition || actualPosition + viewRange < rect.left) {
      return;
    }

    // If the currently visible tooltip is called again, it is ignored.
    if ((_tooltipHideTimer?.isActive ?? false) &&
        _currentVisibleTooltipRect == rect) return;
    _currentVisibleTooltipRect = rect;

    HapticFeedback.vibrate();
    _removeEntry();

    _tooltipController.forward();
    _overlayEntry = OverlayEntry(
      builder: (_) => _buildOverlay(
        rect,
        position,
        barWidth,
        range: range,
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
    DateTimeRange? range,
    double? amount,
    DateTime? amountDate,
  }) {
    final chartType = amount == null ? ChartType.time : ChartType.amount;

    // Get the current widget's position
    final widgetOffset = context.getRenderBoxOffset()!;
    final tooltipSize =
        chartType == ChartType.time ? kTimeTooltipSize : kAmountTooltipSize;

    final candidateTop = rect.top +
        widgetOffset.dy -
        tooltipSize.height / 2 +
        kTimeChartTopPadding +
        (chartType == ChartType.time
            ? (rect.bottom - rect.top) / 2
            : kTooltipArrowHeight / 2);

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

    return Positioned(
      top: tooltipTop,
      left: tooltipLeft,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _tooltipController,
          curve: Curves.fastOutSlowIn,
        ),
        child: TooltipOverlay(
          backgroundColor: widget.tooltipBackgroundColor,
          chartType: chartType,
          bottomHour: bottomHour,
          timeRange: range,
          amountHour: amount,
          amountDate: amountDate,
          direction: direction,
          start: widget.tooltipStart,
          end: widget.tooltipEnd,
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

  void _cancelTimer() {
    _pivotHourUpdatingTimer?.cancel();
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
    if (widget.chartType == ChartType.amount) return false;

    if (notification is ScrollStartNotification) {
      _cancelTimer();
    } else if (notification is ScrollEndNotification) {
      _pivotHourUpdatingTimer =
          Timer(const Duration(milliseconds: 800), _timerCallback);
    }
    return true;
  }

  void _timerCallback() {
    final beforeFirstDataHasChanged = firstDataHasChanged;
    final beforeTopHour = topHour;
    final beforeBottomHour = bottomHour;

    final blockIndex =
        getCurrentBlockIndex(_barController.position, _blockWidth!).toInt();
    final needsToAdaptScrollPosition = blockIndex > 0 && firstDataHasChanged;
    final scrollPositionDuration = Duration(
      days: -blockIndex + (needsToAdaptScrollPosition ? 1 : 0),
    );

    processData(widget, _getFirstItemDate(addition: scrollPositionDuration));

    if (topHour == beforeTopHour && bottomHour == beforeBottomHour) return;

    if (beforeFirstDataHasChanged != firstDataHasChanged) {
      // When a day is added or removed, it is a value to resolve the difference occurring in the x-axis direction.
      final add = firstDataHasChanged ? _blockWidth! : -_blockWidth!;

      _barController.jumpTo(_barController.position.pixels + add);
      _scrollPhysics!.addPanDownPixels(add);
      _scrollPhysics!.setDayCount(dayCount!);
    }

    _runHeightAnimation(beforeTopHour!, beforeBottomHour!);
  }

  double get heightWithoutLabel => widget.height - kXLabelHeight;

  void _runHeightAnimation(int beforeTopHour, int beforeBottomHour) {
    final beforeDiff =
        hourDiffBetween(beforeTopHour, beforeBottomHour).toDouble();
    final currentDiff = hourDiffBetween(topHour, bottomHour).toDouble();

    final candidateUpward = diffBetween(beforeTopHour, topHour!);
    final candidateDownWard = -diffBetween(topHour!, beforeTopHour);

    // (candidate) select one that falls within the current top-bottom hour range
    final topDiff =
        isDirUpward(beforeTopHour, beforeBottomHour, topHour!, bottomHour!)
            ? candidateUpward
            : candidateDownWard;

    setState(() {
      _animationBeginHeight =
          (currentDiff / beforeDiff) * heightWithoutLabel + kXLabelHeight;
      _heightForAlignTop = (_animationBeginHeight - widget.height) / 2 +
          (topDiff / beforeDiff) * heightWithoutLabel;
    });
    _sizeController.reverse(from: 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = widget.width ?? constraints.maxWidth;
        final viewModeLimitDay = widget.viewMode.dayCount;
        final key = ValueKey((topHour ?? 0) + (bottomHour ?? 1) * 100);

        final yLabelWidth = _getRightMargin(context);
        final totalWidth = widget.width ?? constraints.maxWidth;

        _blockWidth ??= (totalWidth - yLabelWidth) / viewModeLimitDay;

        final innerSize = Size(
          _blockWidth! * max(dayCount!, viewModeLimitDay),
          double.infinity,
        );

        _scrollPhysics ??= CustomScrollPhysics(
          blockWidth: _blockWidth!,
          viewMode: widget.viewMode,
          scrollPhysicsState: ScrollPhysicsState(dayCount: dayCount!),
        );

        return SizedBox(
          height: widget.height + kTimeChartTopPadding,
          width: actualWidth,
          child: GestureDetector(
            onPanDown: _handlePanDown,
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                _buildYAxis(totalWidth, key),
                _buildBorder(totalWidth, yLabelWidth, key, innerSize, context),
                _buildBars(totalWidth, yLabelWidth, key, innerSize),
              ],
            ),
          ),
        );
      },
    );
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
            child: _buildHorizontalScrollView(
              key: key,
              controller: _barController,
              child: CanvasTouchDetector(
                gesturesToOverride: const [
                  GestureType.onTapUp,
                  GestureType.onLongPressStart,
                  GestureType.onLongPressMoveUpdate,
                ],
                builder: (context) => CustomPaint(
                  size: innerSize,
                  painter: _buildBarPainter(context),
                ),
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
                  painter: _buildXLabelPainter(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYAxis(
    double totalWidth,
    Key key,
  ) {
    return _buildAnimatedBox(
      topPadding: kTimeChartTopPadding,
      width: totalWidth,
      builder: (context, topPosition) => CustomPaint(
        key: key,
        size: Size(totalWidth, double.infinity),
        painter: _buildYLabelPainter(context, topPosition),
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
    Widget? child,
    required double width,
    double topPadding = 0.0,
    double bottomPadding = 0.0,
    Function(BuildContext, double)? builder,
  }) {
    assert(
        (child != null && builder == null) || child == null && builder != null);

    final heightAnimation = Tween<double>(
      begin: widget.height,
      end: _animationBeginHeight,
    ).animate(_sizeAnimation);
    final heightForAlignTopAnimation = Tween<double>(
      begin: 0,
      end: _heightForAlignTop,
    ).animate(_sizeAnimation);

    return AnimatedBuilder(
      animation: _sizeAnimation,
      builder: (context, child) {
        final topPosition = (widget.height - heightAnimation.value) / 2 +
            heightForAlignTopAnimation.value +
            topPadding;
        return Positioned(
          right: 0,
          top: topPosition,
          child: Container(
            height: heightAnimation.value - bottomPadding,
            width: width,
            alignment: Alignment.center,
            child: child ??
                builder!(
                  context,
                  topPosition - kTimeChartTopPadding,
                ),
          ),
        );
      },
      child: child,
    );
  }

  CustomPainter _buildYLabelPainter(BuildContext context, double topPosition) {
    switch (widget.chartType) {
      case ChartType.time:
        return TimeYLabelPainter(
          context: context,
          viewMode: widget.viewMode,
          topHour: topHour!,
          bottomHour: bottomHour!,
          chartHeight: widget.height,
          topPosition: topPosition,
        );
      case ChartType.amount:
        return AmountYLabelPainter(
          context: context,
          viewMode: widget.viewMode,
          topHour: topHour!,
          bottomHour: bottomHour!,
        );
    }
  }

  CustomPainter _buildXLabelPainter(BuildContext context) {
    final firstValueDateTime =
        processedData.isEmpty ? DateTime.now() : processedData.first.end;
    switch (widget.chartType) {
      case ChartType.time:
        return TimeXLabelPainter(
          scrollController: _xLabelController,
          repaint: _scrollOffsetNotifier,
          context: context,
          viewMode: widget.viewMode,
          firstValueDateTime: firstValueDateTime,
          dayCount: dayCount,
          firstDataHasChanged: firstDataHasChanged,
        );
      case ChartType.amount:
        return AmountXLabelPainter(
          scrollController: _xLabelController,
          repaint: _scrollOffsetNotifier,
          context: context,
          viewMode: widget.viewMode,
          firstValueDateTime: firstValueDateTime,
          dayCount: dayCount,
        );
    }
  }

  CustomPainter _buildBarPainter(BuildContext context) {
    switch (widget.chartType) {
      case ChartType.time:
        return TimeBarPainter(
          scrollController: _barController,
          repaint: _scrollOffsetNotifier,
          context: context,
          tooltipCallback: _tooltipCallback,
          dataList: processedData,
          barColor: widget.barColor,
          topHour: topHour!,
          bottomHour: bottomHour!,
          dayCount: dayCount,
          viewMode: widget.viewMode,
        );
      case ChartType.amount:
        return AmountBarPainter(
          scrollController: _barController,
          repaint: _scrollOffsetNotifier,
          context: context,
          dataList: processedData,
          barColor: widget.barColor,
          topHour: topHour!,
          bottomHour: bottomHour!,
          tooltipCallback: _tooltipCallback,
          dayCount: dayCount,
          viewMode: widget.viewMode,
        );
    }
  }
}
