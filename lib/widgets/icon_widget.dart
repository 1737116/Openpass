import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../providers/providers.dart';
// import '../models/op_icon.dart';
import '../models/database_model.dart';
import '../models/edit_model.dart';
// import '../services/icon_service.dart';
import '../utils/app_icons.dart';

abstract class IconWidgetBase extends ConsumerWidget {
  final double size;
  final bool shadow;
  
  const IconWidgetBase({
    super.key,
    this.size = 24.0,
    this.shadow = false,
  });

  String getTitle(BuildContext context);
  
  /// 获取URL，用于网站图标
  String? getUrl(BuildContext context, WidgetRef ref);
  
  /// 获取KdbxIcon索引
  KdbxIcon getIndexIcon(BuildContext context);
  
  /// 获取自定义图标文件
  KdbxCustomIcon? getIconFile(BuildContext context);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconService = ref.read(iconServiceProvider);
    final url = getUrl(context, ref);
    final indexIcon = getIndexIcon(context);
    final iconFile = getIconFile(context);

    // 优先使用自定义图标文件
    if (iconFile != null) {
      try {
        return _makeIcon(context, Image.memory(
          Uint8List.fromList(iconFile.data),
          width: size,
          height: size,
          fit: BoxFit.contain,
        ));
      } catch(e) {
        // 图片格式错误
      }
    }

    // 其次使用索引图标
    if (indexIcon!=KdbxIcon.key) {
      return _makeIcon(context, SizedBox(
        width: size,
        height: size,
        child: Icon(AppIcons.getIcon(indexIcon), size: size * 0.8),
      ));
    }

    // 再次尝试获取URL图标
    if (url != null && url.isNotEmpty) {
      // 先检查是否有缓存的图标
      final cachedIcon = iconService.getCachedIcon(url);
      if (cachedIcon != null && cachedIcon.image != null) {
        // 如果有缓存，直接使用缓存的图标，避免异步加载
        return _makeIcon(context, SizedBox(
          width: size,
          height: size,
          child: cachedIcon.image,
        ));
      }
      
      // 如果没有缓存，使用 ValueNotifier 保持状态
      return StatefulBuilder(
        builder: (context, setState) {
          // 保存当前显示的图标
          Widget currentIcon = SizedBox(
            width: size,
            height: size,
            child: Icon(AppIcons.getIcon(indexIcon), size: size * 0.8),
          );
          
          // 异步加载图标，但不立即更新UI
          iconService.getIconFromUrl(url).then((opIcon) {
            if (opIcon != null && opIcon.image != null && context.mounted) {
              setState(() {
                currentIcon = SizedBox(
                  width: size,
                  height: size,
                  child: opIcon.image,
                );
              });
            }
          });
          
          return _makeIcon(context, AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: currentIcon,
          ));
        },
      );
    }
    
    // 最后使用文本图标
    {
      // 文本图标
      String displayName = getTitle(context);
      if (displayName.length >= 2) {
        displayName = displayName.substring(0, 2);
      }else if (displayName.length == 1) {
        displayName = displayName;
      }else{
        displayName = '?';
      }
      return _makeIcon(context, Padding(
        padding: EdgeInsets.all(size*0.15),
        child: Center(
          child: AutoSizeText(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ));
    }
  }

  Widget _makeIcon(BuildContext context, Widget icon) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    var color = isDark ? Colors.grey.withAlpha(75) : Colors.white.withAlpha(200);
    var shadowColor = isDark ? Colors.grey.withAlpha(25) : Colors.black.withAlpha(25);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: shadow ? [
          BoxShadow(color: shadowColor,blurRadius: 4,offset: const Offset(0, 2)),
        ]:null,
      ),
      child: icon,
    );
  }
}

/// 普通状态的图标组件，用于显示条目图标
class KdbxIconWidget extends IconWidgetBase {
  final KdbxEntry entry;
  
  const KdbxIconWidget({
    super.key,
    required this.entry,
    super.size,
    super.shadow,
  });

  @override
  String getTitle(BuildContext context) {
    return entry.name;
  }
  
  @override
  String? getUrl(BuildContext context, WidgetRef ref) {
    // 从条目的自定义数据中获取URL，不会动态获取新的图标。
    var opIcon = entry.getCustomValue('op_icon');
    if (opIcon != null) {
      return opIcon;
    }
    return null;
  }
  
  @override
  KdbxIcon getIndexIcon(BuildContext context) {
    return entry.icon;
  }
  
  @override
  KdbxCustomIcon? getIconFile(BuildContext context) {
    if (entry.customIcon != null) {
      final db = entry.db;
      return db.kdbx?.meta.customIcons[entry.customIcon!];
    }
    return null;
  }
}

/// 编辑状态的图标组件，用于编辑条目图标
class EditIconWidget extends IconWidgetBase {
  final EditEntry editEntry;
  final VoidCallback? onTap;
  // final VoidCallback? onIconChanged;
  
  const EditIconWidget({
    super.key,
    required this.editEntry,
    super.size,
    super.shadow,
    this.onTap,
    // this.onIconChanged,
  });
  
  @override
  String getTitle(BuildContext context) {
    return editEntry.name;
  }

  @override
  String? getUrl(BuildContext context, WidgetRef ref) {
    // 从条目的自定义数据中获取URL
    if (editEntry.opIcon != null) {
      return editEntry.opIcon;
    }
    return null;
  }
  
  @override
  KdbxIcon getIndexIcon(BuildContext context) {
    return editEntry.icon ?? KdbxIcon.key;
  }
  
  @override
  KdbxCustomIcon? getIconFile(BuildContext context) {
    return null;
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 使用基类的构建方法显示图标
          super.build(context, ref),
          
          // 添加编辑指示器
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.edit,
                size: size * 0.25,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 文本图标
class TextIconWidget extends IconWidgetBase {
  final String text;
  const TextIconWidget({
    super.key,
    required this.text,
    super.size,
    super.shadow,
  });

  @override
  String getTitle(BuildContext context) {
    return text;
  }
  
  @override
  String? getUrl(BuildContext context, WidgetRef ref) {
    return null;
  }
  
  @override
  KdbxIcon getIndexIcon(BuildContext context) {
    return KdbxIcon.key;
  }
  
  @override
  KdbxCustomIcon? getIconFile(BuildContext context) {
    return null;
  }
}
