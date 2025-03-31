import 'package:flutter/material.dart';
import '../widgets/vault_icon_widget.dart';
import '../utils/vault_icons.dart';

class DbIconSelectionDialog extends StatelessWidget {
  final String selectedIcon;
  final Function(String) onIconSelected;
  final String title;

  const DbIconSelectionDialog({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
    this.title = '选择图标',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: VaultIcons.vaultIconOptions.length,
          itemBuilder: (context, index) {
            final iconPath = VaultIcons.vaultIconOptions[index];
            final isSelected = selectedIcon == iconPath;
            
            return GestureDetector(
              onTap: () {
                onIconSelected(iconPath);
                Navigator.pop(context, iconPath);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withAlpha(25) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: VaultIconWidget(iconName:iconPath),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}