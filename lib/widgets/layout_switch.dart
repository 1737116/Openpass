import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class LayoutSwitch extends ConsumerWidget {
  const LayoutSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutService = ref.watch(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;

    return IconButton(
      icon: Icon(isMobileLayout 
          ? Icons.desktop_windows_outlined  // 移动布局时显示桌面图标
          : Icons.smartphone_outlined       // 桌面布局时显示手机图标)
        ),
      onPressed: () {
        // 改变布局模式
        layoutService.toggleLayout();

        // 重新构建整个应用以应用新布局
        // AppRouter().navigateTo(context, AppPage.main, initialIndex: 2);
      },
      tooltip: isMobileLayout ? '切换到桌面布局' : '切换到移动布局',
    );
  }
}