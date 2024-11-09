import 'package:fic12_flutter_starter/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // Menyimpan produk dari koleksi "products"
  List<String> productNames = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  // Mengambil semua produk dari koleksi "products"
  Future<void> _fetchProducts() async {
    try {
      // Ambil semua produk dari Firestore
      QuerySnapshot productSnapshot = await FirebaseFirestore.instance.collection('products').get();
      List<String> productList = productSnapshot.docs.map((doc) => doc['productName'] as String).toList();

      setState(() {
        productNames = productList; // Simpan produk di state
      });
    } catch (e) {
      print("Error fetching products: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Products',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('history')
            .orderBy('timestamp', descending: true) // Mengurutkan data dari terbaru
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No history available.'));
          }

          var history = snapshot.data!.docs;

          return SingleChildScrollView(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('No.')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Product Name')),
                      DataColumn(label: Text('Availability')),
                    ],
                    rows: history.expand((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      var timestamp = data['timestamp'] != null
                          ? DateFormat('dd MMM yyyy, HH:mm').format((data['timestamp'] as Timestamp).toDate())
                          : 'N/A';
                      var detectedItems = data['detectedItems'] as List<dynamic>? ?? [];

                      return List.generate(detectedItems.length, (index) {
                        var item = detectedItems[index] as Map<String, dynamic>;
                        var productName = item['productName'] ?? 'Unknown';
                        var availability = productNames.contains(productName) ? 'Available' : 'Not Available';

                        return DataRow(cells: [
                          DataCell(Text((index + 1).toString())),
                          DataCell(Text(timestamp)),
                          DataCell(Text(productName)),
                          DataCell(Text(availability)),
                        ]);
                      });
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),

    );
  }
}
