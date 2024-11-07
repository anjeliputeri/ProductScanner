import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/assets/assets.gen.dart';
import 'detection_page.dart';
import 'detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetectionPage(imageFile: File(image.path)),
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image Source"),
          content: Text("Please, choose the source for the image", style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.camera);
              },
              child: Text("Camera", style: TextStyle(color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.gallery);
              },
              child: Text("Gallery", style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('I-EPAPRO', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('history').snapshots(),
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

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      var historyItem = history[index];
                      var timestamp = (historyItem['timestamp'] as Timestamp).toDate();
                      var detectedItems = List<Map<String, dynamic>>.from(historyItem['detectedItems']);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detected at:',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4), // Spacing between texts
                              Text(
                                DateFormat('EEE, dd MMM yyyy').format(timestamp.toLocal()),
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                DateFormat('hh:mm a').format(timestamp.toLocal()),
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                          onTap: () {
                            // Navigate to DetailPage with the detected items
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailPage(items: detectedItems),
                              ),
                            );
                          },
                        ),
                      );
                    },

                  );

                },
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImageSourceDialog,
        backgroundColor: AppColors.primary,
        child: Image.asset(
          Assets.images.products.scanner.path,
          width: 30,
          height: 30,
        ),
        shape: CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
