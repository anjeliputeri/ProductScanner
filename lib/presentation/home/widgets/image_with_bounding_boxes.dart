import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

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

        return Stack(
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

              return Positioned(
                left: x * scaleFactor,
                top: y * scaleFactor,
                child: Container(
                  width: width * scaleFactor,
                  height: height * scaleFactor,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                ),
              );
            }).toList(),
          ],
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
