import 'package:flutter/material.dart';
import '../../../shared/responsive_utils.dart';

class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = Responsive.isCompact(context);
    
    return Padding(
      padding: EdgeInsets.all(rw(context, 24)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          
          // Icon
          Container(
            padding: EdgeInsets.all(rw(context, compact ? 18 : 24)),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: ri(context, compact ? 60 : 80),
              color: iconColor ?? Colors.blue,
            ),
          ),
          
          SizedBox(height: rh(context, 40)),
          
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: rw(context, compact ? 24 : 28),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: rh(context, 20)),
          
          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: rw(context, compact ? 14 : 16),
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
