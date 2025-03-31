import 'package:flutter/material.dart';
import '../utils/password_utils.dart';
import '../services/theme_service.dart';

class PasswordDisplay extends StatelessWidget {
  final String password;
  final bool obscureText;

  const PasswordDisplay({
    super.key,
    required this.password,
    this.obscureText = true,
  });

  @override
  Widget build(BuildContext context) {
    if (obscureText) {
      return Text('•' * password.length, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: themeExtension?.passwordFontFamily,
          fontSize: themeExtension?.passwordFontSize,
          letterSpacing: 1.0,
          // height: 1.5,
        ),
        children: PasswordUtils.colorizePassword(password),
      ),
    );
  }
}