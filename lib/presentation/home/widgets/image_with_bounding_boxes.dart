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
    return FutureBuilder<Size>(
      future: _getImageSize(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final imageSize = snapshot.data!;
        final imageWidth = imageSize.width;
        final imageHeight = imageSize.height;

        final screenWidth = MediaQuery.of(context).size.width;
        final scaleFactor = screenWidth / imageWidth;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Image.file(
                imageFile,
                width: screenWidth,
                fit: BoxFit.fitWidth,
              ),
              if (results.isNotEmpty)
                ...results.map((result) {
                  final rect = result['rect'];
                  if (rect == null) return const SizedBox();

                  final x = rect['x'] * imageWidth * scaleFactor;
                  final y = rect['y'] * imageHeight * scaleFactor;
                  final width = rect['w'] * imageWidth * scaleFactor;
                  final height = rect['h'] * imageHeight * scaleFactor;

                  final productIndex = result['productIndex'];
                  final productColor = result['productColor'];

                  return Positioned(
                    left: x,
                    top: y,
                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: productColor,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              color: productColor.withOpacity(0.7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '$productIndex',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
      image.evict();
    });

    final stream = image.resolve(const ImageConfiguration());
    stream.addListener(listener);
    
    return completer.future;
  }
}

// Optional: If you need to handle multiple images
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
          results: resultsPerImage[currentImage.path] ?? [],
        );
      },
    );
  }
}