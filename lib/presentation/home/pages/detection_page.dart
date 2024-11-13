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
  Map<String, Map<String, List<dynamic>>> _allResultsPerModel = {};
  bool _hasDetected = false;
  bool _isLoading = false;

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

    setState(() {
      _isLoading = true;
    });

    try {
      await _loadModel(_selectedModel!);
      Map<String, List<dynamic>> resultsPerImage = {};

      for (var image in _images!) {
        // Skip detection if bounding boxes already exist
        if (_allResultsPerModel.containsKey(_selectedModel!) &&
            _allResultsPerModel[_selectedModel]!.containsKey(image.path)) {
          // Results already detected for this image, skip detection
          resultsPerImage[image.path] = _allResultsPerModel[_selectedModel!]![image.path]!;
        } else {
          var recognitions = await Tflite.detectObjectOnImage(
            path: image.path,
            threshold: 0.5,
            numResultsPerClass: 5,
          );

          if (recognitions != null) {
            print("-----result----");
            print(recognitions);
            resultsPerImage[image.path] = recognitions;
          }
        }
      }

      setState(() {
        _allResultsPerModel[_selectedModel!] = resultsPerImage;
        _hasDetected = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToFirestore() async {
    try {
      final historyDoc = FirebaseFirestore.instance.collection('history').doc();
      final productsCollection =
      FirebaseFirestore.instance.collection('product');
      final timestamp = DateTime.now();

      final Map<String, Map<String, dynamic>> bestResults = {};

      // Mengumpulkan hasil dari semua model
      _allResultsPerModel.forEach((modelName, resultsPerImage) {
        resultsPerImage.values.forEach((results) {
          for (var result in results) {
            final String productName = result['detectedClass'].toString();
            final double confidence =
            (result['confidenceInClass'] as num).toDouble();

            if (!bestResults.containsKey(productName) ||
                confidence >
                    (bestResults[productName]!['confidence'] as double)) {
              bestResults[productName] = {
                'productName': productName,
                'confidence': confidence,
                'availability': 'Available',
                'model': modelName,  // Tambahkan informasi model
              };
            }
          }
        });
      });

      for (var item in bestResults.values) {
        final productName = item['productName'] as String;

        final productQuery = await productsCollection
            .where('productName', isEqualTo: productName)
            .get();

        if (productQuery.docs.isEmpty) {
          print("-----product belum ada, bikin----");

          await productsCollection.add({
            'productName': productName,
            'availability': 'Available',
            'createdAt': timestamp,
            'updatedAt': timestamp,
          });
        } else {
          print("-----product udah ada, update----");
          final productDoc = productQuery.docs.first;
          await productDoc.reference.update({
            'availability': 'Available',
            'updatedAt': timestamp,
          });
        }
      }

      final List<Map<String, dynamic>> allDetectedItems = bestResults.values
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      await historyDoc.set({
        'timestamp': timestamp,
        'detectedItems': allDetectedItems,
      });

      print("Data saved to Firestore successfully with availability status!");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(results: allDetectedItems),
        ),
      );
    } catch (e) {
      print("Error saving data to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('Product Detection',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.primary,
            iconTheme: IconThemeData(
              color: Colors.white,
            ),
            actions: [
              if (_hasDetected)
                IconButton(
                  icon: Icon(Icons.refresh),
                  color: Colors.white,
                  onPressed: () {
                    setState(() {
                      _images = [XFile(widget.imageFile.path)];
                      _allResultsPerModel.clear();
                      _hasDetected = false;
                      _selectedModel = null;
                    });
                  },
                ),
            ],
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
            onPressed: _hasDetected ? null : _pickImageSource,
            backgroundColor: _hasDetected ? Colors.grey : AppColors.primary,
            child: Image.asset(
              Assets.images.products.scanner.path,
              width: 30,
              height: 30,
              color: _hasDetected ? Colors.white.withOpacity(0.5) : null,
            ),
            shape: CircleBorder(),
          ),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModelDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select Model',
        labelStyle: TextStyle(color: Colors.black87),
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      value: _selectedModel,
      items:
      ['model-1', 'model-2', 'model-3', 'model-4', 'model-5'].map((model) {
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
        Icons.arrow_drop_down,
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
          final currentResults = _selectedModel != null &&
              _allResultsPerModel.containsKey(_selectedModel)
              ? _allResultsPerModel[_selectedModel]![imagePath] ?? []
              : [];

          // Add print statement to debug the results
          print('currentResults: $currentResults');

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
                  results: currentResults,  // Ensure currentResults is a valid list
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
    bool isEnabled = _selectedModel != null;

    return ElevatedButton(
      onPressed: isEnabled ? _detectProducts : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? AppColors.primary : Colors.grey,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        'Detect',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDetectionResults() {
    if (_allResultsPerModel.isEmpty) {
      return Center(
        child: Text(
          "No results detected",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    bool hasValidResults = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        ..._allResultsPerModel.entries.map((modelEntry) {
          final modelName = modelEntry.key;
          final resultsPerImage = modelEntry.value;

          final Map<String, Map<String, dynamic>> uniqueResults = {};

          resultsPerImage.forEach((imagePath, results) {
            for (var result in results) {
              final String productName = removeIdFromText(result['detectedClass'].toString());
              final double confidence = (result['confidenceInClass'] as num).toDouble();

              if (productName.isNotEmpty && !uniqueResults.containsKey(productName) ||
                  confidence > (uniqueResults[productName]!['confidenceInClass'] as num)) {
                uniqueResults[productName] = Map<String, dynamic>.from(result);
                hasValidResults = true; // Mark that valid results exist
              }
            }
          });

          // If there are no valid results for this model, show a fallback message
          if (!hasValidResults) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No valid product detected for $modelName.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection results for $modelName:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ...uniqueResults.values.map((result) {
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(
                      removeIdFromText(result['detectedClass'].toString()) ?? 'Unknown',
                    ),
                  ),
                );
              }).toList(),
              Divider(),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _allResultsPerModel.isNotEmpty ? _saveToFirestore : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),
      child: Text(
        'Save Results',
        style: TextStyle(
            color:
            _allResultsPerModel.isNotEmpty ? AppColors.primary : Colors.grey),
      ),
    );
  }

  String removeIdFromText(String input) {
    List<String> parts = input.split(' ');
    return parts.sublist(0, parts.length - 1).join(' ');
  }
}