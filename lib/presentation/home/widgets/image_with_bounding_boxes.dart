import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ImagesWithBoundingBoxes extends StatelessWidget {
  final List<File> imageFiles; // Daftar gambar yang ingin ditampilkan
  final List<List<dynamic>> allResults; // List hasil deteksi untuk setiap gambar

  const ImagesWithBoundingBoxes({
    Key? key,
    required this.imageFiles,
    required this.allResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: imageFiles.length,
      itemBuilder: (context, index) {
        return ImageWithBoundingBoxes(
          imageFile: imageFiles[index],
          results: allResults[index],
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
    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final imageInfo = snapshot.data!;
        final imageWidth = imageInfo.image.width.toDouble();
        final imageHeight = imageInfo.image.height.toDouble();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10), // memberi jarak antar gambar
          child: Stack(
            children: [
              Image.file(imageFile),
              ...results.map((result) {
                final rect = result['rect'];

                // Hitung koordinat berdasarkan ukuran gambar asli
                final x = rect['x'] * imageWidth;
                final y = rect['y'] * imageHeight;
                final width = rect['w'] * imageWidth;
                final height = rect['h'] * imageHeight;

                // Hitung skala gambar pada layar
                final screenWidth = MediaQuery.of(context).size.width;
                final scaleFactor = screenWidth / imageWidth;

                final confidence = (result['confidenceInClass'] ?? 0) * 100;
                final label = result['detectedClass'] ?? 'Unknown';

                return Positioned(
                  left: x * scaleFactor,
                  top: y * scaleFactor,
                  child: Container(
                    width: width * scaleFactor,
                    height: height * scaleFactor,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            color: Colors.red,
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              '${label.toString().substring(0, 6)}: ${confidence.toStringAsFixed(2)}%',
                              style: TextStyle(
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

  Future<ImageInfo> _getImageInfo() async {
    final completer = Completer<ImageInfo>();
    final image = FileImage(imageFile);
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info);
      }),
    );
    return completer.future;
  }
}
