import 'dart:collection';
import 'dart:math';

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
    final random = Random();

    final date = DateTime.now();

    final from = {
      for (int i = 0; i < 365; i++)
        date.subtract(Duration(days: i)):
            Duration(minutes: random.nextInt(10 * 60)),
    };

    int compare(DateTime a, DateTime b) {
      return b.compareTo(a);
    }

    return SplayTreeMap<DateTime, Duration>.from(
      from,
      compare,
    );
  }();

  late final yearlyData = () {
    final date = DateTime.now();

    final from = {
      for (int i = 0; i < 180; i++)
        date.subtractMonths(i): Duration(
          minutes: (i + 1) * 63,
        ),
    };

    int compare(DateTime a, DateTime b) {
      return b.compareTo(a);
    }

    return SplayTreeMap<DateTime, Duration>.from(
      from,
      compare,
    );
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
                const Text('Weekly amount chart'),
                DurationChart(
                  data: smallDataList,
                  viewMode: ViewMode.weekly,
                  barColor: Colors.deepPurple,
                  onRangeChange: (left, right) {
                    print('$left - $right');
                  },
                ),
                sizedBox,
                const Text('Monthly amount chart'),
                DurationChart(
                  data: smallDataList,
                  viewMode: ViewMode.monthly,
                  barColor: Colors.deepPurple,
                  onRangeChange: (left, right) {
                    print('$left - $right');
                  },
                ),
                sizedBox,
                const Text('Yearly amount chart'),
                DurationChart(
                  data: yearlyData,
                  viewMode: ViewMode.yearly,
                  barColor: Colors.deepPurple,
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
