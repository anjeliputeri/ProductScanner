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
    return Stack(
      children: [
        Image.file(imageFile),
        ...results.map((result) {
          final rect = result['rect'];
          final imageWidth = MediaQuery.of(context).size.width;
          final imageHeight = imageWidth * (imageFile.lengthSync() / (imageFile.lengthSync()));

          final x = rect['x'] * imageWidth;
          final y = rect['y'] * imageHeight;
          final width = rect['w'] * imageWidth;
          final height = rect['h'] * imageHeight;

          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
