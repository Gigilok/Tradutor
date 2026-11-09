import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Tela cheia para ver a foto do chat com zoom e arrastar.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.imageUrl});

  final String imageUrl;

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
            tag: imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Icon(
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
