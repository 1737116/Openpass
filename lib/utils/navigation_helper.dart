import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../pages/detail_page.dart';
import '../pages/detail_edit_page.dart';

class NavigationHelper {
  /// 导航到条目详情页面
  /// 
  /// 在移动设备上，会导航到新页面
  /// 在桌面设备上，只会更新选中的条目，不会导航
  static void navigateToDetail(
    BuildContext context, 
    KdbxEntry item, 
    {
      Function(KdbxEntry?)? onChanged,
    }
  ) {
    // 使用 Riverpod 获取布局服务和条目详情服务
    final container = ProviderScope.containerOf(context);
    final layoutService = container.read(layoutServiceProvider);
    final itemDetailService = container.read(itemDetailServiceProvider);

    // 设置当前选中的条目
    itemDetailService.setSelectedEntry(item, false);
    
    // 判断当前布局类型
    if (layoutService.isMobileLayout) {
      // 移动设备布局，使用导航
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailPage(
            onChanged: onChanged,
          ),
        ),
      );
    }
    // 在桌面布局中，不需要导航，因为详情会显示在第三列
  }

  /// 导航到编辑页
  static Future<void> navigateToDetailEdit(
    BuildContext context,
    KdbxGroup parent,
    KdbxEntry? kdbxEntry,
    {Function(bool)? onChanged}
  ) async {
    final container = ProviderScope.containerOf(context);
    final itemDetailService = container.read(itemDetailServiceProvider);
    final layoutService = container.read(layoutServiceProvider);

    itemDetailService.setEditingEntry(parent, kdbxEntry);
    if (layoutService.isMobileLayout) {
      // 移动设备上，导航到编辑页面
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => DetailEditPage(
            onChanged: (isSaved) async {
              onChanged?.call(isSaved);
              Navigator.pop(context);
            },
          ),
        ),
      );
    } else {
      // 桌面设备上，显示为对话框
      if (kdbxEntry==null){
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: 800, // 对话框宽度
                height: 600, // 对话框高度
                padding: const EdgeInsets.all(0),
                child: DetailEditPage(
                  onChanged: (isSaved) {
                    onChanged?.call(isSaved);
                    Navigator.of(context).pop(); // 关闭对话框
                  },
                ),
              ),
            );
          },
        );
      }else{
        // 无需处理，数据修改后会通知界面自动转换到编辑界面
      }
    }
  }
}