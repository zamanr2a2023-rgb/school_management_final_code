import 'package:flutter/material.dart';
import 'package:high_school/core/constants/app_constants.dart';

/// Garini app mark from [AppConstants.logoAsset].
class GariniLogo extends StatelessWidget {
  const GariniLogo({
    super.key,
    this.size = 88,
    this.fit = BoxFit.contain,
    this.fallbackColor = Colors.white,
  });

  final double size;
  final BoxFit fit;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.logoAsset,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.school_rounded,
          size: size * 0.65,
          color: fallbackColor,
        );
      },
    );
  }
}
