import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fic12_flutter_starter/core/constants/colors.dart';

class ProductsPage extends StatefulWidget {
  @override
  ProductsPageState createState() => ProductsPageState();
}

class ProductsPageState extends State<ProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> productList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final QuerySnapshot productSnapshot = await _firestore.collection('product').get();

      setState(() {
        productList = productSnapshot.docs
            .map((doc) => {
          'id': doc.id,
          'productName': (doc.data() as Map<String, dynamic>)['productName'] as String? ?? 'Unknown',
          'availability': (doc.data() as Map<String, dynamic>)['availability'] as String? ?? 'Unknown',
        })
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching products: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
      }
      return '-';
    } catch (e) {
      return '-';
    }
  }


  String removeIdFromText(String input) {
    List<String> parts = input.split(' ');
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  List<DataRow> _getSortedDataRows(List<Map<String, dynamic>> products, List<DocumentSnapshot> historyDocs) {
    List<Map<String, dynamic>> productsWithDates = [];

    for (var product in products) {
      String lastDetectedDate = '-';
      DateTime? lastDetectedDateTime;

      if (historyDocs.isNotEmpty) {
        for (var doc in historyDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> detectedItems = data['detectedItems'] as List<dynamic>? ?? [];

          for (var item in detectedItems) {
            if (item['productName'] == product['productName']) {
              lastDetectedDate = _formatDate(data['timestamp']);
              lastDetectedDateTime = (data['timestamp'] as Timestamp).toDate();
              break;
            }
          }
          if (lastDetectedDate != '-') break;
        }
      }

      

      productsWithDates.add({
        ...product,
        'lastDetectedDate': lastDetectedDate,
        'lastDetectedDateTime': lastDetectedDateTime,
      });
    }

    productsWithDates.sort((a, b) {
      final DateTime? dateA = a['lastDetectedDateTime'];
      final DateTime? dateB = b['lastDetectedDateTime'];

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return productsWithDates.asMap().entries.map((entry) {
      int index = entry.key;
      var product = entry.value;
      return DataRow(
        cells: [
          DataCell(Text((index + 1).toString())),
          // DataCell(Text(product['lastDetectedDate'])),
          DataCell(
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 250),
              child: Text(
                removeIdFromText(product['productName']),
                style: TextStyle(height: 1.5),
                softWrap: true,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
          DataCell(
            product['availability'] == 'Available'
                ? Icon(Icons.check_circle, color: Colors.green, size: 24)
                : Icon(Icons.cancel, color: Colors.red, size: 24),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Products',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading history: ${snapshot.error}'));
          }

          final List<DataRow> sortedRows = _getSortedDataRows(
            productList,
            snapshot.hasData ? snapshot.data!.docs : [],
          );

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  columns: const [
                    DataColumn(label: Text('No.')),
                    // DataColumn(label: Text('Last Detected')),
                    DataColumn(label: Text('Product Name')),
                    DataColumn(label: Text('Availability')),
                  ],
                  rows: sortedRows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}