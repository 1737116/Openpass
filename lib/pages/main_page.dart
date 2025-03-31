import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../layouts/desktop_layout.dart';
import '../layouts/mobile_layout.dart';

class MainPage extends ConsumerWidget {
  final int initialIndex;

  const MainPage({super.key, required this.initialIndex});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutService = ref.watch(layoutServiceProvider);
    if (layoutService.isMobileLayout){
      return MobileLayout(initialIndex: initialIndex);
    }else{
      return const DesktopLayout();
    }
  }
}
