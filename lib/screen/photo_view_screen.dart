import 'dart:io';

import 'package:flutter/material.dart';

/// Tela cheia para ver a foto do chat com zoom e arrastar.
/// A foto fica guardada no próprio aparelho (chegou pelo servidor).
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Foto'),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Hero(
            tag: imagePath,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
