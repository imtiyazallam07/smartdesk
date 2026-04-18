import 'package:flutter/material.dart';
import '../shared/responsive_utils.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onViewAll;
  final IconData? icon;
  final Color? accentColor;

  const DashboardCard({
    super.key,
    required this.title,
    required this.content,
    required this.onViewAll,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: rw(context, 16), vertical: rw(context, 8)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(rw(context, 20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(rw(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Container(
                          padding: EdgeInsets.all(rw(context, 7)),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(rw(context, 10)),
                          ),
                          child: Icon(icon, size: ri(context, 18), color: accent),
                        ),
                        SizedBox(width: rw(context, 10)),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: rw(context, 15),
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFE5E7EB) : Colors.black87,
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: rw(context, 10), vertical: rw(context, 4)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: accent,
                  ),
                  child: Text('View All', style: TextStyle(fontSize: rw(context, 12), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Divider(
              height: rw(context, 20),
              thickness: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
