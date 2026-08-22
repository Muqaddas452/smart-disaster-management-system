import 'package:flutter/material.dart';

class ReportImage extends StatelessWidget {
  final String imageUrl;

  const ReportImage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image,
          size: 35,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.broken_image,
              size: 35,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }
}