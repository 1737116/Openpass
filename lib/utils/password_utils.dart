import 'package:flutter/material.dart';

class PasswordUtils {
  static List<TextSpan> colorizePassword(String password) {
    List<TextSpan> spans = [];
    for (int i = 0; i < password.length; i++) {
      String char = password[i];
      Color color;
      if (RegExp(r'[0-9]').hasMatch(char)) {
        color = Colors.blue;
      } else if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(char)) {
        color = Colors.red;
      } else {
        color = Colors.black;
      }
      spans.add(TextSpan(
        text: char,
        style: TextStyle(color: color),
      ));
    }
    return spans;
  }

  static double calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;

    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.2;

    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.1;

    return strength.clamp(0.0, 1.0);
  }

  static Color getStrengthColor(double strength) {
    if (strength < 0.3) return Colors.red;
    if (strength < 0.7) return Colors.orange;
    return Colors.green;
  }
  static Color getStrengthColor2(String password) {
    return getStrengthColor(calculatePasswordStrength(password));
  }
}