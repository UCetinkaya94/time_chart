import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_chart/src/time_chart.dart';
import 'package:time_chart/time_chart.dart';

import 'data_pool.dart';

void main() {
  testWidgets('Chart updates when the data is replaced', (tester) async {
    List<DateTimeRange> data = data1;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                DurationChart(data: data),
                TextButton(
                  onPressed: () {
                    setState(() {
                      data = data2;
                    });
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await expectLater(
      find.byType(DurationChart),
      matchesGoldenFile('golden/data1_chart.png'),
      skip: !Platform.isMacOS,
    );

    await tester.tap(find.text('Update'));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(DurationChart),
      matchesGoldenFile('golden/data2_chart.png'),
      skip: !Platform.isMacOS,
    );
  });
}
