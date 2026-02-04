import 'package:flutter/material.dart';
import '../models/feature.dart';

class FeatureCard extends StatelessWidget {
  final Feature feature;

  const FeatureCard({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: feature.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular highlight behind icon
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1), // Subtle overlay
                shape: BoxShape.circle,
              ),
              child: Icon(feature.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            // Title text
            Text(
              feature.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.2, // Line spacing
              ),
            ),
          ],
        ),
      ),
    );
  }
}
