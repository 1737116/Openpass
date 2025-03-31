import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/vault_icons.dart';

class VaultIconWidget extends StatelessWidget {
  final String iconName;
  final double size;
  final BoxFit fit;
  final EdgeInsetsGeometry padding;

  const VaultIconWidget({
    super.key,
    required this.iconName,
    this.size = 24.0,
    this.fit = BoxFit.contain,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      child: SvgPicture.asset(
        'assets/icons/vault/${VaultIcons.checkIcon(iconName)}',
        width: size,
        height: size,
        fit: fit,
      ),
    );
  }
}