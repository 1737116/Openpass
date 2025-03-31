import 'package:flutter/material.dart';
import 'search_overlay.dart';

class CommonSearchBar extends StatelessWidget {
  const CommonSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取当前主题的颜色
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // 根据主题选择适当的背景色
    final backgroundColor = isDarkMode 
        ? theme.colorScheme.surfaceVariant.withAlpha(75)
        : theme.colorScheme.surfaceVariant.withAlpha(25);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SearchBar(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchOverlay(),
              fullscreenDialog: true,
            ),
          );
        },
        hintText: '在全部项目中搜索',
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 13.0,
            color: isDarkMode 
                ? Colors.grey.withAlpha(150) 
                : Colors.grey.withAlpha(125),
          ),
        ),
        leading: const Icon(Icons.search),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: isDarkMode 
                  ? Colors.grey.withAlpha(75) 
                  : Colors.grey.withAlpha(50),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}