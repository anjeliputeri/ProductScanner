import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

class DetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const DetailPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(
          color: Colors.white, // Ubah warna ikon menjadi putih
        ),
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
                    DataColumn(label: Text('Availability')),
                  ],
                  rows: List.generate(items.length, (index) {
                    final item = items[index];
                    return DataRow(cells: [
                      DataCell(Text((index + 1).toString())),
                      DataCell(
                        Text(
                          item['productName'] ?? 'Unknown',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      DataCell(Text(item['availability'] ?? 'N/A')),
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
