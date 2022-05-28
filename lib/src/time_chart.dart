import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:time_chart/src/components/constants.dart';
import 'package:time_chart/src/components/painter/x_painter.dart';
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

  /// Pair of a date and a duration.
  ///
  /// Using a SplayTreeMap ensures, that the dates are correctly sorted
  final SplayTreeMap<DateTime, Duration> data;

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

  int _topHour = 1;

  Offset? _overlayOffset;

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

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      setState(() {
        _topHour = _getMaxHour();
      });
    });
  }

  @override
  void didUpdateWidget(covariant DurationChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
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
            print('tapped');
          },
          child: TooltipOverlay(
            backgroundColor: widget.tooltipBackgroundColor,
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
    final temp = _topHour;

    _topHour = _getMaxHour();
    _runAmountHeightAnimation(temp, currentMax);
    _topHour = currentMax;
  }

  int _getMaxHour() {
    if (!_barController.hasClients) return 8;

    final rightIndex = getRightMostVisibleIndex(
      _barController.position,
      _totalBarWidth!,
    );

    final leftIndex = getLeftMostVisibleIndex(
      rightIndex,
      widget.data.length,
      widget.viewMode.dayCount,
    );

    final visibleItems = widget.data.values
        .toList()
        .getRange(rightIndex.toInt(), leftIndex.toInt() + 1)
        .toList();

    int currentMax = 0;

    for (final item in visibleItems) {
      final hours = item.inHours + 1;

      if (hours > currentMax) {
        currentMax = hours;
      }
    }

    return currentMax;
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
          _totalBarWidth! * max(widget.data.length, viewModeLimitDay),
          double.infinity,
        );

        _scrollPhysics ??= CustomScrollPhysics(
          blockWidth: _totalBarWidth!,
          viewMode: widget.viewMode,
          scrollPhysicsState: ScrollPhysicsState(
            dayCount: widget.data.length,
          ),
        );

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
                        bottomHour: 0,
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

  CustomPainter _buildXLabelPainter(BuildContext context) {
    return XPainter(
      scrollController: _xLabelController,
      repaint: _scrollOffsetNotifier,
      context: context,
      viewMode: widget.viewMode,
      firstValueDateTime: widget.data.isEmpty
          ? DateTime.now() //
          : widget.data.lastKey()!,
      dayCount: widget.data.length,
    );
  }

  CustomPainter _buildBarPainter(BuildContext context) {
    return BarPainter(
      scrollController: _barController,
      repaint: _scrollOffsetNotifier,
      context: context,
      dataMap: widget.data,
      barColor: widget.barColor,
      topHour: _topHour,
      tooltipCallback: _tooltipCallback,
      dayCount: widget.data.length,
      viewMode: widget.viewMode,
    );
  }
}
