import 'package:flutter/material.dart';

class IconManagePage extends StatefulWidget {
  final IconData currentIcon;
  final Function(IconData) onIconSelected;

  const IconManagePage({
    super.key,
    required this.currentIcon,
    required this.onIconSelected,
  });

  @override
  State<IconManagePage> createState() => _IconManagePageState();
}

class _IconManagePageState extends State<IconManagePage> {
  final List<IconData> _defaultIcons = [
    Icons.lock,
    Icons.security,
    Icons.shield,
    Icons.vpn_key,
    Icons.password,
    Icons.key,
    Icons.admin_panel_settings,
    Icons.account_circle,
    Icons.credit_card,
    Icons.wallet,
    Icons.work,
    Icons.home,
    Icons.shopping_bag,
    Icons.favorite,
    Icons.star,
    // 可以添加更多默认图标
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择图标'),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: 实现导入自定义图标
            },
            icon: const Icon(Icons.add),
            tooltip: '导入图标',
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemCount: _defaultIcons.length,
        itemBuilder: (context, index) {
          final icon = _defaultIcons[index];
          final isSelected = icon == widget.currentIcon;
          
          return InkWell(
            onTap: () {
              widget.onIconSelected(icon);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).primaryColor.withAlpha(25)
                    : Colors.grey.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
          );
        },
      ),
    );
  }
}