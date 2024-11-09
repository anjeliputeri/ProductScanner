import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import 'home_page.dart';

class ResultPage extends StatelessWidget {
  final List<dynamic> results;

  const ResultPage({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detection Results',
            style: TextStyle(color: Colors.white)
        ),
      backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 10.0, 5.0, 10.0),
            child: IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Product Name')),
                  ],
                  rows: List.generate(results.length, (index) {
                    final result = results[index];
                    return DataRow(cells: [
                      DataCell(Text((index + 1).toString())),
                      DataCell(
                        Container(
                          child: Text(
                            result['productName'] ?? 'Unknown',
                            style: TextStyle(fontSize: 14),
                            softWrap: true,
                          ),
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
