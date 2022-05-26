import 'dart:math';

import 'package:flutter/material.dart';
import 'package:time_chart/time_chart.dart';

void main() => runApp(MyApp());

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

  @override
  Widget build(BuildContext context) {
    const sizedBox = SizedBox(height: 16);

    final date = DateTime(2021, 2, 26);

    // Data must be sorted.
    var smallDataList = [
      for (int i = 0; i < 90; i++)
        DateTimeRange(
          start: date.add(Duration(days: i)),
          end: date.add(Duration(days: i, minutes: 20 * i)),
        ),
    ];

    smallDataList = smallDataList.reversed.toList();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Time chart example app')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Weekly amount chart'),
                TimeChart(
                  data: smallDataList,
                  chartType: ChartType.amount,
                  viewMode: ViewMode.weekly,
                  barColor: Colors.deepPurple,
                ),
                sizedBox,
                const Text('Monthly amount chart'),
                TimeChart(
                  data: smallDataList,
                  chartType: ChartType.amount,
                  viewMode: ViewMode.monthly,
                  barColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
