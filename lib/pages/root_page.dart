import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'base_page.dart';
import '../models/database_model.dart';
import 'database_new_page.dart';
import 'database_unlock_page.dart';
import '../widgets/add_entry_button.dart';
import '../widgets/common_search_bar.dart';
import '../widgets/vault_icon_widget.dart';

class RootPage extends BasePage {
  final Function()? onItemListSelected;

  const RootPage({
    super.key,
    required super.onSwitchPage,
    this.onItemListSelected,
  });

  @override
  BasePageState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends BasePageState<RootPage> {
  late OPRoot _opRoot;
  List<OPDatabase> databases = [];
  Set<String> _allTags = {};

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

  @override
  Widget buildTitle() {
    final localStorageService = ref.read(localStorageServiceProvider);
    String appIcon = localStorageService.getAppIcon();
    return Row(
      children: [
        // Icon(Icons.watch, size: 30),
        VaultIconWidget(iconName:appIcon, size: 20),
        SizedBox(width: 8),
        Text('保险库'),
      ],
    );
  }
  
  @override
  List<Widget> buildActions() {
    return [
      AddEntryButton(onEntryAdded: () {
        // 刷新数据
        _loadItems();
      }),
    ];
  }
  
  @override
  bool showBackButton() => false;
  
  @override
  Widget buildBody(BuildContext context) {
    final itemListService = ref.read(itemListServiceProvider);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: const CommonSearchBar(),
        ),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 2,
                  child: _buildListTile(
                    itemListService.getAllItemName(),
                    Icon(itemListService.getAllItemIcon()),
                    onTap: () {
                      final itemListService = ref.read(itemListServiceProvider);
                      itemListService.setItemListAll();
                      _onItemListSelected();
                    },
                  ),
                ),
              ),
              _buildRootGroup('保险库', [
                ...databases.map(
                  (db) => _buildListTile(
                    db.name,
                    db.databaseIcon(),
                    isUnlocked: db.isUnlocked,
                    onTap: () {
                      if (db.isUnlocked) {
                        final itemListService = ref.read(itemListServiceProvider);
                        itemListService.setItemListByDatabase(db);
                        _onItemListSelected();
                      } else {
                        _onUnlockDatabase(db);
                      }
                    },
                  ),
                ),
                _buildListTile(
                  '新保险库',
                  Icon(Icons.add, color:Colors.blue),
                  color: Colors.blue,
                  onTap: () {
                    _onNewDatabase();
                  },
                ),
              ]),
              _buildRootGroup(
                  '标签',
                  _allTags
                      .map(
                        (tag) => _buildListTile(
                          tag,
                          Icon(Icons.label_outline),
                          onTap: () {
                            final itemListService = ref.read(itemListServiceProvider);
                            itemListService.setItemListByTag(tag);
                            _onItemListSelected();
                          },
                        ),
                      )
                      .toList()),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 2,
                  child: _buildListTile(
                    itemListService.getAllRecycleBinName(),
                    Icon(itemListService.getAllRecycleBinIcon()),
                    onTap: () {
                      final itemListService = ref.read(itemListServiceProvider);
                      itemListService.setItemListByRecycleBin(null);
                      _onItemListSelected();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRootGroup(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            title: Text(title, style: TextStyle(fontSize: 20)),
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            children: [
              if (children.isEmpty)
                const ListTile(
                  title: Text(
                    '暂无内容',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    Widget icon, {
    Color? color,
    VoidCallback? onTap,
    bool? isUnlocked, // 添加解锁状态参数
  }) {
    return ListTile(
      leading: icon,
      title: Text(title, style: TextStyle(color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnlocked != null)
            Icon(
              isUnlocked ? Icons.lock_open : Icons.lock_outline,
              size: 20,
              color: Colors.grey,
            ),
          Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  void _onItemListSelected() {
    final itemDetailService = ref.read(itemDetailServiceProvider);
    itemDetailService.setSelectedEntry(null, false);

    if (widget.onItemListSelected != null) {
      widget.onItemListSelected!();
    }else{
      widget.onSwitchPage?.call(3);
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
        builder: (context) =>
            UnlockDatabasePage(database: db),
      ),
    ).then((value) {
      _loadItems(); // 刷新列表状态
    });
  }
}
