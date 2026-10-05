import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable application logo widget for Chef&Cost.
///
/// Renders the vector [logo.svg] asset. If [color] is specified,
/// it tints the vector paths; otherwise, it preserves the original
/// warm culinary tones.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 40,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
