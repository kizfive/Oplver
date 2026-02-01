import 'package:flutter/material.dart';

class ThumbnailContainer extends StatelessWidget {
  final Widget child;
  final IconData typeIcon;
  final Color backgroundColor;
  final double? progress; // 0.0 to 1.0

  const ThumbnailContainer({
    super.key,
    required this.child,
    required this.typeIcon,
    required this.backgroundColor,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor, // Theme color darkened
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Content centered and potentially letterboxed
          Center(
            child: child,
          ),
          // Progress Bar (if applicable)
          if (progress != null && progress! > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          // Type icon overlay at bottom right
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(typeIcon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
