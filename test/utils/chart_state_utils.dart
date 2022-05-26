import 'package:flutter_test/flutter_test.dart';
import 'package:time_chart/src/time_chart.dart';

TimeChartState getChartState(WidgetTester tester) {
  return tester.state(find.byType(TimeChart));
}
