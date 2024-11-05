import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';

import '../widgets/image_with_bounding_boxes.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key, required this.imageFile});

  final File imageFile; // Receive the previously captured image

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _images = []; // To store captured images
  String? _selectedModel;
  List _results = [];

  @override
  void initState() {
    super.initState();
    // Initialize with the provided imageFile
    _images!.add(XFile(widget.imageFile.path));
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // Function to choose image source (camera or gallery)
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

// Function to capture image from gallery or camera
Future<void> _captureImage(ImageSource source) async {
  final XFile? image = await _picker.pickImage(source: source);
  if (image != null) {
    setState(() {
      _images!.add(image);
    });
  }
}

// Function to load model
Future<void> _loadModel(String model) async {
  await Tflite.loadModel(
    model: 'assets/models/$model.tflite',
    labels: 'assets/models/$model.txt',
    numThreads: 2,
  );
  print('Model loaded');
}

// Function to perform product detection
Future<void> _detectProducts() async {
  if (_selectedModel == null || _images!.isEmpty) return;

  await _loadModel(_selectedModel!);
  _results.clear();

  print('Detecting products...');

  for (var image in _images!) {
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      threshold: 0.5, // Threshold for detection
      numResultsPerClass: 5,
    );

    if (recognitions != null) { // Check for null
      print("------------result-----------");
      print(recognitions);

      setState(() {
        _results.addAll(recognitions);
      });
    } else {
      print("No recognitions found for ${image.path}");
    }
  }
}

Widget _buildImageWithBoundingBoxes(XFile image, List recognitions) {
  return Stack(
    children: [
      Image.file(File(image.path)), // Display the image
      ...recognitions.map((result) {
        final rect = result['rect']; // Get the bounding box coordinates
        return Positioned(
          left: rect['x'],
          top: rect['y'],
          width: rect['w'],
          height: rect['h'],
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
            ),
          ),
        );
      }).toList(),
    ],
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Product Detection'),
    ),
    body: Column(
      children: [
        DropdownButton<String>(
          hint: Text('Select Model'),
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
        Expanded(
          child: _images!.isNotEmpty
              ? ListView.builder(
            itemCount: _images!.length,
            itemBuilder: (context, index) {
              return ImageWithBoundingBoxes(
                imageFile: File(_images![index].path),
                results: _results, // Pass detection results
              );
            },
          )
              : Center(child: Text('No images captured')),
        ),
        ElevatedButton(
          onPressed: _detectProducts,
          child: Text('Submit & Detect'),
        ),
        Expanded(
          child: _results.isNotEmpty
              ? ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return ListTile(
                title: Text(result['detectedClass'] ?? 'Unknown'),
                subtitle: Text('Confidence: ${(result['confidence'] != null ? (result['confidence'] * 100).toStringAsFixed(2) : '0.00')}%'),
              );
            },
          )
              : Center(child: Text('No detection results available')),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _pickImageSource,
      backgroundColor: Colors.blue,
      child: Icon(Icons.add_a_photo),
      shape: CircleBorder(),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  );
}
}
