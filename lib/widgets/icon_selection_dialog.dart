import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../providers/providers.dart';
import '../utils/app_icons.dart';
import '../widgets/icon_widget.dart';

class IconSelectionDialog {
  static Future<KdbxIcon?> show(BuildContext context, {
    required KdbxIcon? selectedIcon,
    String title = '选择图标',
  }) async {
    final layoutService = ProviderScope.containerOf(context).read(layoutServiceProvider);
    final isMobileLayout = layoutService.isMobileLayout;
    
    if (isMobileLayout) {
      return await showModalBottomSheet<KdbxIcon>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _IconSelectionContent(
          selectedIcon: selectedIcon??KdbxIcon.key,
          title: title,
        ),
      );
    } else {
      return await showDialog<KdbxIcon>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 400,
            child: _IconSelectionContent(
              selectedIcon: selectedIcon??KdbxIcon.key,
              title: title,
              isDialog: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      );
    }
  }
}

class _IconSelectionContent extends StatelessWidget {
  final KdbxIcon selectedIcon;
  final String title;
  final bool isDialog;

  const _IconSelectionContent({
    required this.selectedIcon,
    required this.title,
    this.isDialog = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDialog) Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!isDialog) const SizedBox(height: 16),
          
          // // 自动获取图标选项
          // ListTile(
          //   leading: const Icon(Icons.auto_awesome, color: Colors.blue),
          //   title: const Text('自动获取图标'),
          //   subtitle: const Text('根据URL自动获取网站图标'),
          //   onTap: () {
          //     Navigator.pop(context, KdbxIcon.key);
          //   },
          // ),
          
          // const Divider(),
          
          // 图标网格
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: AppIcons.allIcons.length,
              itemBuilder: (context, index) {
                final iconName = AppIcons.allIcons[index];
                final isSelected = selectedIcon == iconName;
                
                return InkWell(
                  onTap: () {
                    Navigator.pop(context, iconName);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withAlpha(50) : Colors.grey.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected 
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: iconName==KdbxIcon.key
                        ? TextIconWidget(text:'自动', size: 60, shadow: false,)
                        : Icon(AppIcons.getIcon(iconName),
                          color: isSelected ? Colors.blue : Colors.grey[700],
                          size: 28,
                        ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}