import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../services/theme_service.dart';
import '../widgets/vault_icon_widget.dart';
import 'database_new_page.dart';
import 'database_unlock_page.dart';


class SidebarPage extends ConsumerStatefulWidget {
  final Function()? onItemListSelected;
  final Function(String menu)? onClickMenu;

  const SidebarPage({
    super.key,
    this.onItemListSelected,
    this.onClickMenu
  });

  @override
  ConsumerState<SidebarPage> createState() => SidebarPageState();
}

class SidebarPageState extends ConsumerState<SidebarPage> {
  late OPRoot _opRoot;
  List<OPDatabase> databases = [];
  Set<String> _allTags = {};
  String _selectedItem = '';
  String _nickname = '';
  String _appIcon = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final itemListService = ref.read(itemListServiceProvider);
    final root = itemListService.opRoot;
    setState(() {
      _opRoot = root;
      _allTags = _opRoot.allTags;
      databases = _opRoot.allDatabases;
    });
  }

  // 添加刷新方法
  void refresh() {
    if (mounted) {
      setState(() {
        _allTags = _opRoot.allTags;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final layoutService = ref.watch(layoutServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    
    return Container(
      color: themeExtension?.sidebarBackgroundColor,
      child: Column(
        children: [
          // 数据库选择器
          _buildMainMenuBar(),
          
          // // 搜索栏
          // if (layoutService.isMobileLayout) Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: const CommonSearchBar(),
          // ),

          // 主要导航项
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 20),

                // // 快速访问
                // _buildNavItem('快速访问', Icon(Icons.push_pin,size:20), onTap: () {
                //   itemListService.setItemListAll();
                //   _onItemListSelected('快速访问');
                // }),

                // 所有项目
                _buildNavItem('所有项目', Icon(Icons.folder,size:20), onTap: () {
                  itemListService.setItemListAll();
                  _onItemListSelected('所有项目');
                }),
                
                // 收藏夹
                _buildNavItem('收藏夹', Icon(Icons.star,size:20), color: Colors.amber, onTap: () {
                  itemListService.setItemListByFavorites();
                  _onItemListSelected('收藏夹');
                }),

                // // 开发者
                // _buildNavItem('开发者', Icons.code, color: Colors.teal, onTap: () {
                //   // 实现开发者功能
                //   _onItemListSelected('开发者');
                // }),

                // 分类间隔
                const SizedBox(height: 16),
                
                // 保险库分组
                _buildExpandableGroup('保险库', [
                  ...databases.map(
                    (db) => _buildNavItem(
                      db.name,
                      db.databaseIcon(size:20),
                      onTap: () {
                        if (db.isUnlocked) {
                          itemListService.setItemListByDatabase(db);
                          _onItemListSelected(db.name);
                        } else {
                          _onUnlockDatabase(db);
                        }
                      },
                    ),
                  ),
                ], showAddButton: true, onAddPressed: _onNewDatabase),

                // 分类间隔
                const SizedBox(height: 16),
                
                // 标签分组
                _buildExpandableGroup('标签', [
                  ..._allTags.map(
                    (tag) => _buildNavItem(
                      tag,
                      Icon(Icons.label, size:20),
                      color: Colors.green,
                      onTap: () {
                        itemListService.setItemListByTag(tag);
                        _onItemListSelected(tag);
                      },
                    ),
                  ),
                ]),

                // 分类间隔
                const SizedBox(height: 16),
                
                // // 存档
                // _buildNavItem('存档', Icons.archive, onTap: () {
                //   // 实现存档功能
                //   _onItemListSelected('存档');
                // }),
                
                // 最近删除
                _buildNavItem('最近删除', Icon(Icons.delete_outline), onTap: () {
                  itemListService.setItemListByRecycleBin(null);
                  _onItemListSelected('最近删除');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 用户菜单
  Widget _buildMainMenuBar() {
    final localStorageService = ref.read(localStorageServiceProvider);
    _nickname = localStorageService.getNickname();
    _appIcon = localStorageService.getAppIcon();
    
    return InkWell(
      onTap: () {
        // 显示数据库选择菜单
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: PopupMenuButton(
          itemBuilder: (context) => _buildMainMenu(),
          position: PopupMenuPosition.under,
          offset: Offset(35, 0),
          child: Row(
            children: [
              // Icon(Icons.watch, color: Colors.blue), // 用户设定的图标
              VaultIconWidget(iconName:_appIcon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry> _buildMainMenu() {
    final List<PopupMenuEntry> items = [
      // PopupMenuItem(
      //   onTap: () => {},
      //   child: Row(
      //     children: [
      //       const Icon(Icons.qr_code, size: 20),
      //       const SizedBox(width: 12),
      //       const Text('扫描二维码'),
      //     ],
      //   ),
      // ),
      PopupMenuItem(
        onTap: () => { widget.onClickMenu?.call('setting') },
        child: Row(
          children: [
            const Icon(Icons.settings, size: 20),
            const SizedBox(width: 12),
            const Text('设置'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: () => { widget.onClickMenu?.call('lock') },
        child: Row(
          children: [
            const Icon(Icons.logout, size: 20),
            const SizedBox(width: 12),
            const Text('锁定'),
          ],
        ),
      ),
    ];
    return items;
  }

  Widget _buildNavItem(
    String title,
    Widget icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    bool isSelected = _selectedItem == title;
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    
    // 使用主题中定义的颜色
    final selectedBackgroundColor = themeExtension?.sidebarSelectedItemColor;
    final textColor = isSelected 
        ? themeExtension?.sidebarSelectedTextColor 
        : themeExtension?.sidebarTextColor;
    // final iconColor = color ?? (isSelected 
    //     ? themeExtension?.sidebarSelectedIconColor 
    //     : themeExtension?.sidebarIconColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isSelected ? selectedBackgroundColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6.0),
      ),
      // color: isSelected ? Theme.of(context).colorScheme.surfaceVariant : null,
      child: ListTile(
        dense: true,
        leading: icon,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            // color: isSelected 
            //     ? Theme.of(context).colorScheme.primary 
            //     : Colors.black87,
            color: textColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: onTap,
        selectedTileColor: Colors.transparent,
        horizontalTitleGap: 8.0,
      ),
    );
  }

  Widget _buildExpandableGroup(
    String title,
    List<Widget> children, {
    bool showAddButton = false,
    VoidCallback? onAddPressed,
  }) {
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    final titleColor = themeExtension?.sidebarGroupTitleColor;
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: titleColor,
          ),
        ),
        trailing: showAddButton 
            ? IconButton(
                icon: Icon(Icons.add, size: 18, color: titleColor),
                onPressed: onAddPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        controlAffinity: ListTileControlAffinity.leading, // 展开标记放在左边
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 8.0),
        initiallyExpanded: true,
        iconColor: titleColor, // 展开图标颜色
        collapsedIconColor: titleColor, // 折叠图标颜色
        children: children,
      ),
    );
  }

  void _onItemListSelected(String itemName) {
    final itemDetailService = ref.read(itemDetailServiceProvider);
    itemDetailService.setSelectedEntry(null, false);

    setState(() {
      _selectedItem = itemName;
    });
    
    if (widget.onItemListSelected != null) {
      widget.onItemListSelected!();
    } else {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => ListPage(),
      //   ),
      // );
    }
  }

  void _onNewDatabase() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const NewDatabasePage(),
      ),
    ).then((value) {
      if (value == true) {
        _loadItems();
      }
    });
  }

  void _onUnlockDatabase(OPDatabase db) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UnlockDatabasePage(database: db),
      ),
    ).then((value) {
      _loadItems(); // 刷新列表状态
    });
  }
}