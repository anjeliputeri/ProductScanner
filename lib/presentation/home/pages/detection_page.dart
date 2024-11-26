import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fic12_flutter_starter/core/constants/colors.dart';
import 'package:fic12_flutter_starter/presentation/home/pages/result_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'dart:math' as math;

import '../../../core/assets/assets.gen.dart';
import '../widgets/image_with_bounding_boxes.dart';


class ProductInfo {
    final int index;
    final Color color;
    final String cleanName;

    ProductInfo({
      required this.index,
      required this.color,
      required this.cleanName,
    });
  }
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

  final Map<String, ProductInfo> _productInfo = {};
  int _nextProductIndex = 1;
  int _colorIndex = 0;

  final Map<String, int> _globalProductIndices = {};

   // Add a map to store product colors
  final Map<String, Color> _productColors = {};
  
  // Extended list of distinct colors for products
  final List<Color> _availableColors = [
    const Color(0xFFE57373), // Red 300
    const Color(0xFF64B5F6), // Blue 300
    const Color(0xFF81C784), // Green 300
    const Color(0xFFBA68C8), // Purple 300
    const Color(0xFFFFB74D), // Orange 300
    const Color(0xFF4DB6AC), // Teal 300
    const Color(0xFFF06292), // Pink 300
    const Color(0xFF7986CB), // Indigo 300
    const Color(0xFFFFD54F), // Amber 300
    const Color(0xFF4DD0E1), // Cyan 300
    const Color(0xFF9575CD), // Deep Purple 300
    const Color(0xFFA1887F), // Brown 300
    const Color(0xFF90A4AE), // Blue Grey 300
    const Color(0xFFAED581), // Light Green 300
    const Color(0xFFFF8A65), // Deep Orange 300
    const Color(0xFFF06292), // Pink 300
    const Color(0xFF7E57C2), // Deep Purple 400
    const Color(0xFF66BB6A), // Green 400
    const Color(0xFF5C6BC0), // Indigo 400
    const Color(0xFFFF7043), // Deep Orange 400
    const Color(0xFF26A69A), // Teal 400
    const Color(0xFFEC407A), // Pink 400
    const Color(0xFF26C6DA), // Cyan 400
    const Color(0xFFFFCA28), // Amber 400
  ];
  
  

  // Modified to use consistent product info
  String removeIdFromText(String input) {
    List<String> parts = input.split(' ');
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  // Get or create product info
  ProductInfo _getOrCreateProductInfo(String rawProductName) {
    final cleanName = removeIdFromText(rawProductName);
    
    if (!_productInfo.containsKey(cleanName)) {
      _productInfo[cleanName] = ProductInfo(
        index: _nextProductIndex++,
        color: _availableColors[_colorIndex % _availableColors.length],
        cleanName: cleanName,
      );
      _colorIndex++;
    }
    
    return _productInfo[cleanName]!;
  }

  Color _getProductColor(String productName) {
    // Assign color if not exists
    if (!_productColors.containsKey(productName)) {
      _productColors[productName] = _availableColors[_colorIndex % _availableColors.length];
      _colorIndex++;
    }
    
    // Assign global index if not exists
    if (!_globalProductIndices.containsKey(productName)) {
      _globalProductIndices[productName] = _nextProductIndex++;
    }
    
    return _productColors[productName]!;
  }

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
          title: const Text("Choose Image Source"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.camera);
              },
              child: const Text("Camera"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _captureImage(ImageSource.gallery);
              },
              child: const Text("Gallery"),
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

  bool _doBoxesOverlap( box1, box2) {
    double x1 = box1['rect']['x'];
    double y1 = box1['rect']['y'];
    double w1 = box1['rect']['w'];
    double h1 = box1['rect']['h'];
    
    double x2 = box2['rect']['x'];
    double y2 = box2['rect']['y'];
    double w2 = box2['rect']['w'];
    double h2 = box2['rect']['h'];

    return !(x1 + w1 < x2 || x2 + w2 < x1 || y1 + h1 < y2 || y2 + h2 < y1);
  }

  double _calculateOverlapArea( box1,  box2) {
    double x1 = box1['rect']['x'];
    double y1 = box1['rect']['y'];
    double w1 = box1['rect']['w'];
    double h1 = box1['rect']['h'];
    
    double x2 = box2['rect']['x'];
    double y2 = box2['rect']['y'];
    double w2 = box2['rect']['w'];
    double h2 = box2['rect']['h'];

    double xOverlap = math.max(0, math.min(x1 + w1, x2 + w2) - math.max(x1, x2));
    double yOverlap = math.max(0, math.min(y1 + h1, y2 + h2) - math.max(y1, y2));
    
    return xOverlap * yOverlap;
  }


  Future<void> _detectProducts() async {
    if (_selectedModel == null || _images!.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _loadModel(_selectedModel!);
      // Simpan hasil deteksi sementara
      Map<String, List<dynamic>> tempResultsPerImage = {};

      for (var image in _images!) {
        print('Processing image: ${image.path}');
        var recognitions = await Tflite.detectObjectOnImage(
          path: image.path,
          threshold: 0.5,
          numResultsPerClass: 5,
        );

        print('Raw recognitions: $recognitions');

        if (recognitions != null && recognitions.isNotEmpty) {
          List<dynamic> newDetections = List.from(recognitions);

          List<dynamic> processedRecognitions = recognitions.map((recognition) {
            if (recognition['detectedClass'] != null) {
              final productInfo = _getOrCreateProductInfo(recognition['detectedClass']);
              
              return {
                ...recognition,
                'cleanProductName': productInfo.cleanName,
                'productIndex': productInfo.index,
                'productColor': productInfo.color,
              };
            }
            return recognition;
          }).toList();
          List<dynamic> finalDetections = [];

          // Cek hasil deteksi sebelumnya untuk semua model
          print('Previous results per model: $_allResultsPerModel');
          for (var newDetection in processedRecognitions) {
            bool shouldKeep = true;
            var conflictingDetection;
            String? conflictingModel;
            

            print('check overlap');
            // Periksa overlap dengan deteksi dari model lain
            for (var modelName in _allResultsPerModel.keys) {
              if (modelName == _selectedModel) continue;

              var previousResults = _allResultsPerModel[modelName]?[image.path];
              if (previousResults == null) continue;
              print('previeous result: $previousResults');

              for (var prevDetection in previousResults) {
                if (_doBoxesOverlap(newDetection, prevDetection)) {
                  print('Detected overlapping boxes: $newDetection and $prevDetection');
                  double overlapArea = _calculateOverlapArea(newDetection, prevDetection);
                  print('overlap area: $overlapArea');
                  double box1Area = newDetection['rect']['w'] * newDetection['rect']['h'];
                  double box2Area = prevDetection['rect']['w'] * prevDetection['rect']['h'];

                  if (overlapArea > 0.3 * math.min(box1Area, box2Area)) {
                    print('Detected overlapping boxes: $newDetection and $prevDetection');
                    if (newDetection['confidenceInClass'] <= prevDetection['confidenceInClass']) {
                      shouldKeep = false;
                      break;
                    } else {
                      conflictingDetection = prevDetection;
                      conflictingModel = modelName;
                    }
                  } else {
                    print('Detected non-overlapping boxes: $newDetection and $prevDetection');
                  }
                }
              }

              if (!shouldKeep) break;
            }

            if (shouldKeep) {
              finalDetections.add(newDetection);
              // Jika ada deteksi yang konflik dan confidence baru lebih tinggi
              if (conflictingDetection != null && conflictingModel != null) {
                _allResultsPerModel[conflictingModel]![image.path]!
                    .remove(conflictingDetection);
                if (_allResultsPerModel[conflictingModel]![image.path]!.isEmpty) {
                  _allResultsPerModel[conflictingModel]!.remove(image.path);
                }
              }
            }
          }

          if (finalDetections.isNotEmpty) {
            tempResultsPerImage[image.path] = finalDetections;
          }
        }
      }

      setState(() {
        if (tempResultsPerImage.isNotEmpty) {
          _allResultsPerModel[_selectedModel!] = tempResultsPerImage;
        }
        _hasDetected = true;
      });

      print('Current results per model: $_allResultsPerModel');
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
                'model': modelName, // Tambahkan informasi model
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
            title: const Text('Product Detection',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(
              color: Colors.white,
            ),
            actions: [
              if (_hasDetected)
                IconButton(
                  icon: const Icon(Icons.refresh),
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
            shape: const CircleBorder(),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: const Column(
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
        labelStyle: const TextStyle(color: Colors.black87),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
            style: const TextStyle(
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
      icon: const Icon(
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
              final allResults = <String, List<dynamic>>{};
              
              // Collect results from all models for this image
              _allResultsPerModel.forEach((model, resultsPerImage) {
                if (resultsPerImage.containsKey(imagePath)) {
                  allResults[imagePath] = resultsPerImage[imagePath]!;
                }
              });

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
                      results: allResults[imagePath] ?? [],
                    ),
                  ),
                ),
              );
            },
          ),
        )
      : const Center(child: Text("No images selected"));
}

  Widget _buildDetectButton() {
    bool isEnabled = _selectedModel != null;

    return ElevatedButton(
      onPressed: isEnabled ? _detectProducts : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? AppColors.primary : Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text(
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
      return const Center(
        child: Text(
          "No results detected",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    // Create a map to store the best results across all models
    final Map<String, Map<String, dynamic>> bestResults = {};

    // Process results from all models
    _allResultsPerModel.forEach((modelName, resultsPerImage) {
      resultsPerImage.forEach((imagePath, results) {
        for (var result in results) {
          if (result['detectedClass'] != null) {
            final String cleanName = result['cleanProductName'];
            final double confidence = (result['confidenceInClass'] as num).toDouble();

            if (!bestResults.containsKey(cleanName) ||
                confidence > (bestResults[cleanName]!['confidenceInClass'] as num)) {
              bestResults[cleanName] = {
                ...result,
                'modelName': modelName,
              };
            }
          }
        }
      });
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 5),
          child: Text(
            'Detection Results:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        ...bestResults.entries.map((entry) {
          final result = entry.value;
          final confidence = (result['confidenceInClass'] as num) * 100;
          final modelName = result['modelName'];
          final productColor = result['productColor'];
          final productIndex = result['productIndex'];

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: productColor.withOpacity(0.3),
                  border: Border.all(
                    color: productColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '$productIndex',
                    style: TextStyle(
                      color: productColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              title: Text(entry.key),
              subtitle: Text(
                'Confidence: ${confidence.toStringAsFixed(1)}% (${modelName})',
              ),
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),
      child: Text(
        'Save Results',
        style: TextStyle(
            color: _allResultsPerModel.isNotEmpty
                ? AppColors.primary
                : Colors.grey),
      ),
    );
  }


}
