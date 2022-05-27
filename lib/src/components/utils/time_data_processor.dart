import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/src/components/painter/chart_engine.dart';
import '../../../time_chart.dart';
import 'time_assistant.dart' as time_assistant;

const String _kNotSortedDataErrorMessage =
    'The data list is reversed or not sorted. Check the data parameter. The first data must be newest data.';

/// 데이터를 적절히 가공하는 믹스인이다.
///
/// 이 믹스인은 [topHour]와 [bottomHour] 등을 계산하기 위해 사용한다.
///
/// 위의 두 기준 시간을 구하는 알고리즘은 다음과 같다.
/// 1. 주어진 데이터들에서 현재 차트에 표시되어야 하는 데이터만 고른다. 즉, 차트의 오른쪽 시간과 왼쪽 시간에
///    포함되는 데이터만 고른다. 이때 좌, 우로 하루씩 허용오차를 두어 차트가 잘못 그려지는 것을 방지한다.
/// 2. 선택된 데이터를 이용하여 기준 값들을 먼저 구해본다. 기준 값은 데이터에서 가장 공백이 큰 시간 범위를
///    찾아 반환한다.
/// 3. 구해진 기준 값 중 [bottomHour]과 24시 사이에 있는 데이터들에 각각 하루 씩 더한다.
///
/// 위와 같은 과정을 지나면 [_processedData]에는 기준 시간에 맞게 수정된 데이터들이 들어있다.
mixin TimeDataProcessor {
  static const Duration _oneDayDuration = Duration(days: 1);

  /// 현재 [DurationChart]의 상태에 맞게 가공된 데이터를 반환한다.
  ///
  /// [bottomHour]와 24시 사이에 있는 데이터들을 다음날로 넘어가 있다.
  List<DateTimeRange> get processedData => _processedData;
  List<DateTimeRange> _processedData = [];

  final List<DateTimeRange> _inRangeDataList = [];

  int? get topHour => _topHour;
  int? _topHour;

  int? get bottomHour => _bottomHour;
  int? _bottomHour;

  int? get dayCount => _dayCount;
  int? _dayCount;

  set topHour(int? value) => _topHour = value;

  /// 첫 데이터가 [bottomHour]에 의해 다음날로 넘겨진 경우 `true` 이다.
  ///
  /// 이때 [dayCount]가 7 이상이어야 한다.
  bool get firstDataHasChanged => _firstDataHasChanged;
  bool _firstDataHasChanged = false;

  void processData(DurationChart chart, DateTime renderEndTime,
      [int? leftIndex, int? rightIndex]) {
    if (chart.data.isEmpty) {
      _handleEmptyData(chart);
      return;
    }

    _processedData = [...chart.data];

    _firstDataHasChanged = false;
    _countDays(chart.data);
    _generateInRangeDataList(chart.data, chart.viewMode, renderEndTime);
    _calcAmountPivotHeights(chart.data);
  }

  void _handleEmptyData(DurationChart chart) {
    _topHour = 8;
    _bottomHour = 0;
    _dayCount = 0;
  }

  void _countDays(List<DateTimeRange> dataList) {
    assert(dataList.isNotEmpty);

    final firstDateTime = dataList.first.end;
    final lastDateTime = dataList.last.end;

    if (dataList.length > 1) {
      assert(firstDateTime.isAfter(lastDateTime), _kNotSortedDataErrorMessage);
    }
    _dayCount = firstDateTime.differenceDateInDay(lastDateTime) + 1;
  }

  /// 입력으로 들어온 [dataList]에서 [renderEndTime]부터 [viewMode]의 제한 일수 기간 동안 포함된
  /// [_inRangeDataList]를 만든다.
  void _generateInRangeDataList(
    List<DateTimeRange> dataList,
    ViewMode viewMode,
    DateTime renderEndTime,
  ) {
    renderEndTime = renderEndTime.add(
      const Duration(days: ChartEngine.toleranceDay),
    );
    final renderStartTime = renderEndTime.add(Duration(
      days: -viewMode.dayCount - 2 * ChartEngine.toleranceDay,
    ));

    _inRangeDataList.clear();

    DateTime postEndTime =
        dataList.first.end.add(_oneDayDuration).dateWithoutTime();
    for (int i = 0; i < dataList.length; ++i) {
      if (i > 0) {
        assert(
          dataList[i - 1].end.isAfter(dataList[i].end),
          _kNotSortedDataErrorMessage,
        );
      }
      final currentTime = dataList[i].end.dateWithoutTime();
      // 이전 데이터와 날짜가 다른 경우
      if (currentTime != postEndTime) {
        final difference = postEndTime.differenceDateInDay(currentTime);
        // 하루 이상 차이나는 경우
        postEndTime = postEndTime.add(Duration(days: -difference));
      }
      postEndTime = currentTime;

      if (renderStartTime.isBefore(currentTime) &&
          currentTime.isBefore(renderEndTime)) {
        _inRangeDataList.add(dataList[i]);
      }
    }
  }

  void _calcAmountPivotHeights(List<DateTimeRange> dataList) {
    const double infinity = 10000.0;
    final int len = dataList.length;

    double maxResult = 0.0;
    double minResult = infinity;
    double sum = 0.0;

    for (int i = 0; i < len; ++i) {
      final amount = dataList[i].durationInHours;
      sum += amount;

      if (i == len - 1 ||
          dataList[i].end.dateWithoutTime() !=
              dataList[i + 1].end.dateWithoutTime()) {
        maxResult = max(maxResult, sum);
        if (sum > 0.0) {
          minResult = min(minResult, sum);
        }
        sum = 0.0;
      }
    }

    _topHour = maxResult.ceil();
    _bottomHour = minResult == infinity ? 0 : max(0, minResult.floor() - 1);
  }

  /// [b]에서 [a]로 흐른 시간을 구한다. 예를 들어 5시에서 3시로 흐른 시간은 22시간이고,
  /// 16시에서 19시로 흐른 시간은 3시간이다.
  ///
  /// 이를 역으로 이용하여 끝 시간으로부터 시작 시간을 구할 수 있다.
  /// [b]에 총 시간 크기를 넣고 [a]에 끝 시간을 넣으면 시작 시간이 반환된다.
  dynamic hourDiffBetween(dynamic a, dynamic b) {
    final c = b - a;
    if (c <= 0) return 24.0 + c;
    return c;
  }
}
