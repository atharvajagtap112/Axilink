import 'dart:typed_data';
import 'package:flutter/material.dart';

class OptimizedImageView extends StatelessWidget {
  final Uint8List imageData;
  
  const OptimizedImageView({Key? key, required this.imageData}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Image.memory(
      imageData,
      gaplessPlayback: true, // Prevents flickering between frames
      filterQuality: FilterQuality.low, // Faster rendering
      fit: BoxFit.contain,
    );
  }
}
