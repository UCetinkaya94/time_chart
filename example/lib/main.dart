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

  List<DateTimeRange> getRandomSampleDataList() {
    final List<DateTimeRange> list = [];
    final random = Random();

    for (int i = 0; i < 10000; ++i) {
      final int randomMinutes1 = random.nextInt(59);
      final int randomMinutes2 = random.nextInt(59);
      final start = DateTime(2021, 2, 1 - i, 0, randomMinutes1);
      final end = DateTime(2021, 2, 1 - i, 7, randomMinutes2 + randomMinutes1);

      list.add(DateTimeRange(
        start: start,
        end: end,
      ));
    }
    return list;
  }

  late final List<DateTimeRange> bigDataList = getRandomSampleDataList();

  late final smallDataList = () {
    final random = Random();

    final date = DateTime.now();

    final from = {
      for (int i = 0; i < 90; i++)
        date.subtract(Duration(days: i)):
            Duration(minutes: random.nextInt(10 * 60)),
    };

    int compare(DateTime a, DateTime b) {
      return b.compareTo(a);
    }

    // Data must be sorted.
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
                ),
                sizedBox,
                /*  const Text('Monthly amount chart'),
                DurationChart(
                  data: smallDataList,
                  viewMode: ViewMode.monthly,
                  barColor: Colors.deepPurple,
                ), */
              ],
            ),
          ),
        ),
      ),
    );
  }
}
