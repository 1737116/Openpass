import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class ThemeSwitch extends ConsumerWidget {
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);
    
    return IconButton(
      icon: Icon(
        themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
      ),
      onPressed: () {
        themeService.toggleTheme();
      },
      tooltip: themeService.isDarkMode ? '切换到浅色模式' : '切换到深色模式',
    );
  }
}