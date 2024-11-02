import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';

void main() => runApp(DetectApp());

class DetectApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Produk Detector',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ProductDetectionScreen(),
    );
  }
}

class ProductDetectionScreen extends StatefulWidget {
  @override
  _ProductDetectionScreenState createState() => _ProductDetectionScreenState();
}

class _ProductDetectionScreenState extends State<ProductDetectionScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images = []; // Untuk menyimpan gambar yang di-capture
  String? _selectedModel;
  List _results = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // Fungsi untuk mengambil gambar dari galeri atau kamera
  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _images!.add(image);
      });
    }
  }

  // Fungsi untuk memuat model
  Future<void> _loadModel(String model) async {
    await Tflite.loadModel(
      model: 'assets/models/$model.tflite',
      labels: 'assets/models/$model.txt',
      numThreads: 2,
    );
    print('Model loaded');
  }

  // Fungsi untuk melakukan deteksi produk
  Future<void> _detectProducts() async {
    if (_selectedModel == null || _images!.isEmpty) return;

    await _loadModel(_selectedModel!);
    _results.clear();

    print('Detecting products...');

    for (var image in _images!) {
      var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        threshold: 0.5,        // Threshold hasil deteksi
        numResultsPerClass: 5,
      );
      print("------------result-----------");
      print(recognitions);

      setState(() {
        _results.addAll(recognitions!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Produk Detection'),
      ),
      body: Column(
        children: [
          DropdownButton<String>(
            hint: Text('Pilih Model'),
            value: _selectedModel,
            items: ['model-1', 'model-2', 'model-3', 'model-4', 'model-5'].map((model) {
              return DropdownMenuItem(
                value: model,
                child: Text(model),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedModel = value;
              });
            },
          ),
          ElevatedButton(
            onPressed: _captureImage,
            child: Text('Capture Image'),
          ),
          Expanded(
            child: _images!.isNotEmpty
                ? ListView.builder(
                    itemCount: _images!.length,
                    itemBuilder: (context, index) {
                      return Image.file(File(_images![index].path));
                    },
                  )
                : Center(child: Text('No images captured')),
          ),
          ElevatedButton(
            onPressed: _detectProducts,
            child: Text('Submit & Detect'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  title: Text(result['detectedClass']),
                  subtitle: Text(
                      'Confidence: ${result['confidence']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
