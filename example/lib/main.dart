import 'package:flutter/material.dart';
import 'package:time_chart/time_chart.dart';

class ScrollBehaviorModified extends ScrollBehavior {
  const ScrollBehaviorModified();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MyApp(),
  );
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  late final smallDataList = () {
    final date = DateTime.now();

    return {
      for (int i = 0; i < 10000; i++)
        date.subtract(Duration(days: i)): Duration(minutes: (i + 1) * 5),
    };
  }();

  late final yearlyData = () {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);

    return {
      for (int i = 0; i < 180; i++)
        DateTime(date.year, date.month - i): Duration(
          minutes: (i + 1) * 63,
        ),
    };
  }();

  @override
  Widget build(BuildContext context) {
    const sizedBox = SizedBox(height: 16);

    return MaterialApp(
      builder: (context, widget) {
        return ScrollConfiguration(
            behavior: const ScrollBehaviorModified(), child: widget!);
      },
      home: Scaffold(
        appBar: AppBar(title: const Text('Time chart example app')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                /*  const Text('Weekly amount chart'),
                DurationChart(
                  rawData: smallDataList,
                  viewMode: ViewMode.weekly,
                  barColor: Colors.deepPurple,
                  onTapOverlay: (date) {},
                  onRangeChange: (left, right) {
                    print('$left - $right');
                  },
                ),
                sizedBox,
                const Text('Monthly amount chart'),
                DurationChart(
                  rawData: smallDataList,
                  viewMode: ViewMode.monthly,
                  barColor: Colors.deepPurple,
                  onTapOverlay: (date) {},
                  onRangeChange: (left, right) {
                    print('$left - $right');
                  },
                ),
                sizedBox, */
                const Text('Yearly amount chart'),
                DurationChart(
                  rawData: yearlyData,
                  viewMode: ViewMode.yearly,
                  barColor: Colors.deepPurple,
                  onTapOverlay: (date) {},
                  onRangeChange: (left, right) {
                    print('$left - $right');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
