import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fic12_flutter_starter/core/constants/colors.dart';
import 'package:fic12_flutter_starter/presentation/home/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';

import '../../../core/assets/assets.gen.dart';
import '../widgets/image_with_bounding_boxes.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images = [];
  String? _selectedModel;
  Map<String, List<dynamic>> _resultsPerImage = {};

  @override
  void initState() {
    super.initState();
    _images!.add(XFile(widget.imageFile.path));
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Future<void> _pickImageSource() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choose Image Source"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.camera);
              },
              child: Text("Camera"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.gallery);
              },
              child: Text("Gallery"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _captureImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _images!.add(image);
      });
    }
  }

  Future<void> _loadModel(String model) async {
    await Tflite.loadModel(
      model: 'assets/models/$model.tflite',
      labels: 'assets/models/$model.txt',
      numThreads: 2,
    );
    print('Model loaded');
  }

  Future<void> _detectProducts() async {
    if (_selectedModel == null || _images!.isEmpty) return;

    await _loadModel(_selectedModel!);
    _resultsPerImage.clear();

    for (var image in _images!) {
      var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        threshold: 0.5,
        numResultsPerClass: 5,
      );

      if (recognitions != null) {
        print("-----result----");
        print(recognitions);
        setState(() {
           _resultsPerImage[image.path] = recognitions;
        });
      }
    }
  }

  Future<void> _saveToFirestore() async {
    try {
      final historyDoc = FirebaseFirestore.instance.collection('history').doc();
      final timestamp = DateTime.now();

      final allDetectedItems = _resultsPerImage.values.expand((results) {
        return results.map((result) {
          return {
            'productName': result['detectedClass'],
            'confidence': result['confidenceInClass'],
            'availability': 'Available',
          };
        });
      }).toList();

      await historyDoc.set({
        'timestamp': timestamp,
        'detectedItems': allDetectedItems,
      });

      print("Data saved to Firestore successfully with availability status!");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(results: allDetectedItems), // Pass results to ResultPage
        ),
      );
    } catch (e) {
      print("Error saving data to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Detection', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: IconThemeData(
          color: Colors.white, // Ubah warna ikon menjadi putih
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePreview(),
              const SizedBox(height: 20),
              _buildModelDropdown(),
              const SizedBox(height: 20),
              _buildDetectButton(),
              const SizedBox(height: 20),
              _buildDetectionResults(),
              const SizedBox(height: 20),
              _buildSaveButton(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImageSource,
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

  Widget _buildModelDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select Model',
        labelStyle: TextStyle(color: Colors.black87), // Warna label
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2), // Border warna biru
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2), // Border fokus tetap warna biru
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2), // Border ketika tidak fokus tetap warna biru
        ),
        filled: true,
        fillColor: Colors.white, // Latar belakang dropdown
      ),
      value: _selectedModel,
      items: ['model-1', 'model-2', 'model-3', 'model-4', 'model-5']
          .map((model) {
        return DropdownMenuItem(
          value: model,
          child: Text(
            model,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedModel = value;
        });
      },
      icon: Icon(
        Icons.arrow_drop_down, // Ikon dropdown
        color: AppColors.primary,
      ),
      iconSize: 30,
    );

  }

  Widget _buildImagePreview() {
    return _images!.isNotEmpty
        ? Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images!.length,
              itemBuilder: (context, index) {
                final imagePath = _images![index].path;
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ImageWithBoundingBoxes(
                        imageFile: File(imagePath),
                        // Hanya memberikan hasil deteksi yang sesuai dengan gambar ini
                        results: _resultsPerImage[imagePath] ?? [],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        : Center(child: Text("No images selected"));
  }

  Widget _buildDetectButton() {
    return ElevatedButton(
      onPressed: _detectProducts,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Adjust this value to make the corners less rounded
        ),
      ),
      child: Text('Detect',
          style: TextStyle(
              fontSize: 14,
              color: Colors.white)),
    );
  }

  Widget _buildDetectionResults() {
    // Menampilkan hasil deteksi untuk semua gambar
    return _resultsPerImage.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              ..._resultsPerImage.entries.expand((entry) {
                final imageIndex = _images!.indexWhere((img) => img.path == entry.key);
                return [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 5),
                    child: Text(
                      'Image ${imageIndex + 1} Results:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ...entry.value.map((result) {
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(result['detectedClass'] ?? 'Unknown'),
                        subtitle: Text(
                          'Confidence: ${(result['confidenceInClass'] != null ? (result['confidenceInClass'] * 100).toStringAsFixed(2) : '0.00')}%',
                        ),
                      ),
                    );
                  }).toList(),
                ];
              }).toList(),
            ],
          )
        : Center(
            child: Text(
              "No results detected",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _resultsPerImage.isNotEmpty ? _saveToFirestore : null, // Tombol hanya aktif jika ada hasil deteksi
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: AppColors.primary,
            width: 2,
          ), // Menambahkan border dengan warna dan ketebalan
        ),
      ),
      child: Text(
        'Save Results',
        style: TextStyle(color: _resultsPerImage.isNotEmpty ? AppColors.primary : Colors.grey), // Mengubah warna teks jika tombol dinonaktifkan
      ),
    );
  }

}
