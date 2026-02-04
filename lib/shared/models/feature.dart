import 'package:flutter/material.dart';

class Feature {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  Feature({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
