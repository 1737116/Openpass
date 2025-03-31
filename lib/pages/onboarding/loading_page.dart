import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

// 加载画面应用
class LoadingPage extends ConsumerWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);
    final themeMode = themeService.themeMode;
    
    return MaterialApp(
      title: 'OpenPass',
      theme: themeService.getThemeData(context, isDark: false),
      darkTheme: themeService.getThemeData(context, isDark: true),
      themeMode: themeMode,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image.asset('assets/images/logo.png', width: 120, height: 120),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在加载...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}