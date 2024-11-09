import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ImagesWithBoundingBoxes extends StatelessWidget {
  final List<File> imageFiles;
  final Map<String, List<dynamic>> resultsPerImage;

  const ImagesWithBoundingBoxes({
    Key? key,
    required this.imageFiles,
    required this.resultsPerImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: imageFiles.length,
      itemBuilder: (context, index) {
        final currentImage = imageFiles[index];
        return ImageWithBoundingBoxes(
          imageFile: currentImage,
          // Mengambil hasil deteksi yang sesuai dengan path gambar
          results: resultsPerImage[currentImage.path] ?? [],
        );
      },
    );
  }
}

class ImageWithBoundingBoxes extends StatelessWidget {
  final File imageFile;
  final List<dynamic> results;

  const ImageWithBoundingBoxes({
    Key? key,
    required this.imageFile,
    required this.results,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _getImageSize(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final imageSize = snapshot.data!;
        final imageWidth = imageSize.width;
        final imageHeight = imageSize.height;

        // Dapatkan ukuran layar dan hitung faktor skala
        final screenWidth = MediaQuery.of(context).size.width;
        final scaleFactor = screenWidth / imageWidth;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Stack(
            clipBehavior: Clip.none, // Mencegah pemotongan bounding box
            children: [
              Image.file(
                imageFile,
                width: screenWidth,
                fit: BoxFit.fitWidth,
              ),
              if (results.isNotEmpty) // Hanya tampilkan bounding box jika ada hasil
                ...results.map((result) {
                  final rect = result['rect'];
                  if (rect == null) return const SizedBox(); // Skip jika tidak ada rect

                  // Hitung koordinat dengan skala yang benar
                  final x = rect['x'] * imageWidth * scaleFactor;
                  final y = rect['y'] * imageHeight * scaleFactor;
                  final width = rect['w'] * imageWidth * scaleFactor;
                  final height = rect['h'] * imageHeight * scaleFactor;

                  final confidence = (result['confidenceInClass'] ?? 0.0) * 100;
                  final label = result['detectedClass'] ?? 'Unknown';

                  // Tentukan apakah label harus dipotong
                  final displayLabel = label.length > 6 
                      ? '${label.substring(0, 6)}...' 
                      : label;

                  return Positioned(
                    left: x,
                    top: y,
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Label container
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              color: Colors.red.withOpacity(0.7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '$displayLabel: ${confidence.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<Size> _getImageSize() async {
    final completer = Completer<Size>();
    final image = FileImage(imageFile);
    
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      completer.complete(size);
      image.evict(); // Bersihkan cache gambar
    });

    final stream = image.resolve(const ImageConfiguration());
    stream.addListener(listener);
    
    return completer.future;
  }
}