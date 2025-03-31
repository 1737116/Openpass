import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../providers/providers.dart';
import 'base_page.dart';
import '../models/database_model.dart';
import '../services/item_list_service.dart';
import '../widgets/database_label.dart';
import '../widgets/add_entry_button.dart';
import '../widgets/entry_list_tile.dart';
import '../widgets/folder_select_sheet.dart';

class ListPage extends BasePage {

  const ListPage({
    super.key,
    super.onSwitchPage,
  });

  @override
  BasePageState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends BasePageState<ListPage> {
  final GlobalKey _folderButtonKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late ItemListService _itemListService;
  List<KdbxItem> _items = [];
  Map<String, List<KdbxItem>> _groupedItems = {};
  List<KdbxGroup> _parentFolders = [];
  bool _isSearchVisible = false;
  bool _isShowTree = false;
  bool _isDbReadonly = false;
  bool _isInRecycleBin = false;
  KdbxGroup? _currentFolder;
  String _currentFolderName = "";

  @override
  void initState() {
    super.initState();
    _itemListService = ref.read(itemListServiceProvider);
    _itemListService.addListener(_refreshView);
    _loadItems(refreshParent:false);

    _searchController.addListener(() {
      _itemListService.search(_searchController.text);
      _loadItems();
    });
  }

  @override
  void dispose() {
    _itemListService.removeListener(_refreshView);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refreshView() {
    _loadItems();
  }

  Future<void> _loadItems({bool refreshParent = true}) async {
    final itemListService = _itemListService;
    final showType = itemListService.getShowType();
    final db = itemListService.getShowDatabase();
    final items = itemListService.getItems();
    var folder = itemListService.getCurrentFolder();
    final isReadonly = db?.isReadonly ?? false;
    _isInRecycleBin = showType==ListViewType.byRecycleBin;
    _isShowTree = itemListService.isShowTree();
    setState(() {
      _isDbReadonly = isReadonly;
      _items = items;
      if (!_isShowTree) {
        _groupedItems = makeGroupedItems(items);
      }
      _currentFolder = folder;
      _currentFolderName = itemListService.getFolderName(folder);
    });
    if (refreshParent){
      widget.onSwitchPage?.call(null);
    }
  }

  Map<String, List<KdbxItem>> makeGroupedItems(List<KdbxItem> items) {
    final itemListService = ref.read(itemListServiceProvider);
    Map<String, List<KdbxItem>> groupedItems = {};
    // var showType = _itemService.getShowType();
    var sortType = itemListService.getSortType();
    if (sortType == ItemSortMethod.modifyTime) {
      for (KdbxItem item in items) {
        String month = '${item.modifiedAt.year}年${item.modifiedAt.month}月';
        if (!groupedItems.containsKey(month)) {
          groupedItems[month] = [];
        }
        groupedItems[month]!.add(item);
      }
    } else if (sortType == ItemSortMethod.createTime) {
      for (KdbxItem item in items) {
        String month = '${item.createdAt.year}年${item.createdAt.month}月';
        if (!groupedItems.containsKey(month)) {
          groupedItems[month] = [];
        }
        groupedItems[month]!.add(item);
      }
    } else {
      for (KdbxItem item in items) {
        String firstChar = item.name.substring(0, 1);
        // 如果是数字，转换成 '#'
        if (firstChar.codeUnitAt(0) >= 48 && firstChar.codeUnitAt(0) <= 57) {
          firstChar = '#';
        }
        if (!groupedItems.containsKey(firstChar)) {
          groupedItems[firstChar] = [];
        }
        groupedItems[firstChar]!.add(item);
      }
    }
    return groupedItems;
  }

  @override
  Widget buildTitle() {
    return _buildFolderTitle(context);
  }
  
  @override
  List<Widget> buildActions() {
    return [
      AddEntryButton(onEntryAdded: () {
        _loadItems();
      }),
    ];
  }
  
  @override
  PreferredSizeWidget? buildAppBarBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48.0),
      child: Container(
        height: 48.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Expanded(child: _isSearchVisible// 搜索框 or 位置 or NULL
              ? _buildSearchBar()
              : (_isShowTree && _currentFolder != null)
                ? DatabaseLabel(db: _currentFolder!.db)
                : SizedBox.shrink(),
            ),
            _buildSearchBtn(), // 搜索按钮
            _buildSortBtn(), // 排序按钮
          ],
        ),
      ),
    );
  }
  
  @override
  bool showBackButton() {
    final itemListService = ref.read(itemListServiceProvider);
    return !itemListService.isTopFolder();
  }
  
  @override
  void onBackPressed() {
    final layoutService = ref.watch(layoutServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    // 跳转到上一层文件夹
    if (itemListService.setItemListUpFolder()) {
      _loadItems();
    } else if (layoutService.isMobileLayout) {
      widget.onSwitchPage?.call(1); // 返回上一层
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final layoutService = ref.watch(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;
    if (isMobileLayout){
      return _buildListView(context, isMobileLayout);
    }else{
      // 桌面布局
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: _scrollController.hasClients && _scrollController.offset > 0 
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                      spreadRadius: 1,
                    )
                  ] 
                : [],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildFolderBackBtn(context),
                          Expanded(child:_buildFolderTitle(context)),
                        ],
                      ),
                    ),
                    Row(children: [
                      _buildSearchBtn(),
                      _buildSortBtn(),
                    ]),
                  ],
                ),
                // 桌面布局也使用 AnimatedContainer 实现平滑过渡
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isSearchVisible ? null : 0,
                  child: _isSearchVisible 
                    ? _buildSearchBar() 
                    : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildListView(context, isMobileLayout),
          ),
        ],
      );
    }
  }

  

  Widget _buildFolderBackBtn(BuildContext context){
    if (showBackButton()){
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        // splashRadius: 20, // 减小水波纹半径
        // splashColor: Colors.transparent, // 设置水波纹为透明
        // hoverColor: Colors.transparent, // 设置悬停颜色为透明
        // highlightColor: Colors.transparent, // 设置高亮颜色为透明
        onPressed: onBackPressed,
      );
    }else{
      return SizedBox.fromSize(size: const Size.square(36));
    }
  }

  Widget _buildFolderTitle(BuildContext context){
    final itemListService = ref.read(itemListServiceProvider);
    return itemListService.isShowTree()
      ? InkWell(
          key: _folderButtonKey,
          onTap: () => _showFolderMenu(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              itemListService.getFolderIcon(_currentFolder),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _currentFolderName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        )
        : Text(
          itemListService.getShowTypeText(),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );
  }

  Widget _buildSearchBtn() {
    return IconButton(
      icon: Icon(Icons.search,
        color: _isSearchVisible ? Colors.blue : Colors.grey),
      onPressed: () {
        setState(() {
          _isSearchVisible = !_isSearchVisible; // 切换搜索框显示状态
          if (_isSearchVisible) {
            // 如果显示搜索框，滚动到顶部并设置焦点
            // _scrollController.animateTo(
            //   0,
            //   duration: const Duration(milliseconds: 300),
            //   curve: Curves.easeInOut,
            // );
            // 延迟设置焦点，确保搜索框已经渲染
            Future.delayed(const Duration(milliseconds: 100), () {
              _searchFocusNode.requestFocus();
            });
          }
        });
        widget.onSwitchPage?.call(null);
      },
    );
  }
  
  Widget _buildListView(BuildContext context, bool isMobileLayout) {
    List<Widget> children = [];


    if (!_isShowTree) {
      _groupedItems.forEach((groupName, items) {
        children.add(_buildGroupSection(context, groupName));
        int idx = 0;
        for (var item in items) {
          if (idx > 0) {
            children.add(_buildDivider(context));
          }
          children.add(_buildListItem(context, item, isMobileLayout));
          ++idx;
        }
      });
    } else {
      int idx = 0;
      for(var item in _items){
        if (idx > 0) {
          children.add(_buildDivider(context));
        }
        if (item is KdbxEntry){
          children.add(_buildListItem(context, item, isMobileLayout));
        }else{
          children.add(_buildListFolder(context, item as KdbxGroup));
        }
        ++idx;
      }
    }
    return ListView(
      controller: _scrollController, // 添加控制器
      children: children,
    );
  }

  // Widget _buildSearchBar() {
  //   String name = _isShowTree ? '当前目录' : _itemService.getShowTypeText();
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //     child: SearchBar(
  //       focusNode: _searchFocusNode,
  //       hintText: '在$name中查找',
  //       leading: const Icon(Icons.search),
  //       elevation: WidgetStateProperty.all(0), // 设置阴影为0
  //       backgroundColor: WidgetStateProperty.all(Colors.grey[80]), // 设置浅灰色背景
  //       onChanged: (value) {
  //         _itemService.search(value);
  //         _loadItems();
  //       },
  //     ),
  //   );
  // }
  Widget _buildSearchBar() {
    final itemListService = ref.read(itemListServiceProvider);
    String name = _isShowTree ? '当前目录' : itemListService.getShowTypeText();
    
    return SearchBar(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: '在$name中查找',
      hintStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 13.0,
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey.withAlpha(150) 
              : Colors.grey.withAlpha(125),
        ),
      ),
      leading: const Icon(Icons.search, size: 18),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, child) {
            return value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : const SizedBox.shrink();
          },
        ),
      ],
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).brightness == Brightness.dark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(75)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(25)
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey.withAlpha(75) 
                : Colors.grey.withAlpha(50),
            width: 0.5,
          ),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8.0),
      ),
      onChanged: (value) {
        // 控制器监听器中已处理
      },
    );
  }

  // 分组名字
  Widget _buildGroupSection(BuildContext context, String groupName) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        groupName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 60.0, right: 25.0),
      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
    );
  }

  Widget _buildListItem(BuildContext context, KdbxItem item, bool isMobileLayout) {
    final itemDetailService = ref.read(itemDetailServiceProvider);
    final selectedColor = Colors.blue.withAlpha(25);
    final isSelected = itemDetailService.isSelected(item);
    
    return Container(
      color: isSelected ? selectedColor : Colors.transparent,
      child: KeyedSubtree(
        key: ValueKey(item.id),
        child: item is KdbxEntry
            ? _buildListEntry(context, item, isMobileLayout)
            : _buildListFolder(context, item as KdbxGroup),
      ),
    );

    // return KeyedSubtree(
    //   key: ValueKey(item.id),
    //   child: item is KdbxEntry
    //       ? _buildListEntry(context, item)
    //       : _buildListFolder(context, item as KdbxGroup),
    // );
  }

  Widget _buildListEntry(BuildContext context, KdbxEntry item, bool isMobileLayout) {
    return EntryListTile(
      item: item,
      isMobileLayout: isMobileLayout,
      onChanged: () async {
        await _loadItems();
      },
    );
  }

  Widget _buildListFolder(BuildContext context, KdbxGroup folder) {
    String name = folder.folderName;
    String desc = '${folder.children.length} 个项目';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: folder.folderIcon(color: Colors.blue),
      ),
      title: Text(name),
      subtitle: Text(
        desc,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // 跳转到子文件夹
        final itemListService = ref.read(itemListServiceProvider);
        itemListService.setItemListByFolder(folder);
        _loadItems();
      },
    );
  }

  void onClickDeleteButton(){
    // 永久删除操作
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除'),
        content: const Text('此操作不可撤销，确定要永久删除此项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 执行永久删除逻辑
              // _deleteEntry();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
  }

  // 添加显示文件夹菜单的方法
  void _showFolderMenu(BuildContext context) {
    final RenderBox? button =
        _folderButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + button.size.height,
      buttonPosition.dx + button.size.width,
      buttonPosition.dy + button.size.height,
    );

    // 获取当前路径的所有上层文件夹
    final itemListService = ref.read(itemListServiceProvider);
    _parentFolders = itemListService.getParentFolders(false, !_isInRecycleBin);
    final isDir = _parentFolders.isNotEmpty;

    List<PopupMenuEntry<String>> menus = [];

    // 当前文件夹信息
    menus.add(PopupMenuItem<String>(
      enabled: false,
      height: 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(itemListService.getShowFolderName()),
          Text(
            '${itemListService.getCurrentFolderEntityCount()} 个项目',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    ));
    menus.add(const PopupMenuDivider());

    // 上层文件夹列表
    for (var folder in _parentFolders) {
      menus.add(PopupMenuItem<String>(
        value: folder.uuid.string,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            folder.folderOrDbIcon(color: Colors.blue, size: 20),
            const SizedBox(width: 12),
            Text(itemListService.getFolderName(folder)),
          ],
        ),
      ));
    }
    if (_isInRecycleBin && _currentFolder!=null) {
      menus.add(PopupMenuItem<String>(
        value: "[ROOT]",
        child: Row(
          children: [
            const Icon(Icons.folder_delete, color: Colors.blue, size: 20),
            const SizedBox(width: 12),
            Text('回收站'),
          ],
        ))
      );
    }

    // 文件夹操作
    if (!_isDbReadonly) {
      menus.add(const PopupMenuDivider());
      if (_isInRecycleBin) {
        if (_currentFolder == null) {
          menus.add(_build1MenuItem('clearAllRecycleBin', '清空所有回收站', Icons.delete_forever, isRed:true));
        } else if (_currentFolder == _currentFolder!.db.recycleBin) {
          menus.add(_build1MenuItem('clearOneRecycleBin', '清空回收站', Icons.delete_forever, isRed:true));
        } else {
          menus.add(_build1MenuItem('recover', '恢复', Icons.restore_outlined));
          menus.add(_build1MenuItem('delete2', '删除', Icons.delete_outline, isRed:true));
        }
      }else {
        menus.add(_build1MenuItem('new_folder', '新建目录', Icons.create_new_folder_outlined));
        if (isDir) {
          menus.add(_build1MenuItem('rename', '重新命名', Icons.edit_outlined));
          menus.add(_build1MenuItem('copy', '拷贝', Icons.copy_outlined));
          menus.add(_build1MenuItem('move', '移动', Icons.drive_file_move_outline));
          menus.add(_build1MenuItem('delete', '删除', Icons.delete_outline, isRed:true));
        }
      }
    }

    showMenu<String>(
      context: context,
      position: position,
      items: menus,
    ).then((value) {
      if (value == null) return;

      // 处理菜单选择
      final itemListService = ref.read(itemListServiceProvider);
      if (_parentFolders.any((folder) => folder.uuid.string == value)) {
        // 导航到选中的文件夹
        itemListService.setItemListByFolderId(value);
        _loadItems();
      } else {
        // 处理其他操作
        switch (value) {
          case '[ROOT]':
            itemListService.setItemListByFolder(null);
            _loadItems();
            break;
          case 'rename':
            _renameCurrentFolder();
            break;
          case 'new_folder':
            _newFolderInCurrentFolder();
            break;
          case 'copy':
            // TODO: 实现拷贝功能
            break;
          case 'move':
            _moveCurrentFolder();
            break;
          case 'delete':
            _deleteCurrentFolder('删除目录');
            break;
          case 'delete2':
            _deleteCurrentFolder('彻底删除目录');
            break;
          case 'recover':
            _recoverCurrentFolder();
            break;
          case 'clearAllRecycleBin':
            onClickDeleteButton();
            break;
          case 'clearOneRecycleBin':
            onClickDeleteButton();
            break;
        }
      }
    });
  }

  PopupMenuEntry<String> _build1MenuItem(String value, String text, IconData icon, {bool isRed=false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 12),
          Text(text, style: isRed?TextStyle(color: Colors.red):null),
        ],
      ),
    );
  }

  void _renameCurrentFolder() {
    final itemListService = ref.read(itemListServiceProvider);
    _showNameDialog(
      title: '重命名',
      initialValue: itemListService.getShowFolderName(),
      onConfirm: (newName) {
        if (newName.isNotEmpty) {
          final itemListService = ref.read(itemListServiceProvider);
          itemListService.renameCurrentFolder(newName);
          _loadItems();
        }
      },
    );
  }

  void _newFolderInCurrentFolder() {
    _showNameDialog(
      title: '新建目录',
      hintText: '请输入目录名称',
      onConfirm: (name) {
        if (name.isNotEmpty) {
          final itemListService = ref.read(itemListServiceProvider);
          itemListService.createFolder(name);
          _loadItems();
        }
      },
    );
  }

  void _moveCurrentFolder() async {
    final itemListService = ref.read(itemListServiceProvider);
    var folder = itemListService.getCurrentFolder();
    KdbxGroup? exclude = folder;
    final selectedFolder = await FolderSelectSheet.show(
      context,
      initialFolder: folder,
      excludeFolder: exclude,
    );
    if (selectedFolder != null) {
      // 用户选择了一个文件夹
      print('Selected folder: ${selectedFolder.name}');
      itemListService.moveCurrentFolderTo(selectedFolder);
      _loadItems();
    } else {
      // 用户取消了选择
      print('Selection cancelled');
    }
  }

  void _recoverCurrentFolder() {
    final itemListService = ref.read(itemListServiceProvider);
    itemListService.recoverCurrentFolder();
    final itemDetailService = ref.read(itemDetailServiceProvider);
    itemDetailService.setSelectedEntry(null, false);
  }

  void _deleteCurrentFolder(String title) async {
    final itemListService = ref.read(itemListServiceProvider);
    final itemDetailService = ref.read(itemDetailServiceProvider);
    var db = itemListService.getShowDatabase();
    var folder = itemListService.getCurrentFolder();
    if (db == null || folder == null) return;
    // 显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('确定要$title ${folder.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == true) {
      // 删除文件夹
      itemListService.deleteCurrentFolder();
      itemDetailService.setSelectedEntry(null, false);
      _loadItems();
    }
  }

  Widget _buildSortBtn() {
    return PopupMenuButton(
      icon: const Icon(Icons.more_horiz),
      itemBuilder: (context) => _buildSortMenu(),
      position: PopupMenuPosition.under,
    );
  }

  List<PopupMenuEntry> _buildSortMenu() {
    final itemListService = ref.read(itemListServiceProvider);
    final currentType = itemListService.getSortType();
    final isAscending = itemListService.getSortAscending();

    final List<PopupMenuEntry> items = [
      // 显示条目数量部分保持不变
      PopupMenuItem(
        enabled: false,
        height: 36,
        child: Text(
          '${_items.length} 个项目',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ),
      const PopupMenuDivider(),
      // 排序类型
      PopupMenuItem(
        onTap: () => _onTapSortMenuItem(0, false),
        child: Row(
          children: [
            if (currentType == ItemSortMethod.name)
              const Icon(Icons.check, size: 20, color: Colors.blue)
            else
              const SizedBox(width: 20),
            const Icon(Icons.sort_by_alpha, size: 20),
            const SizedBox(width: 12),
            const Text('名称'),
          ],
        ),
      ),
      PopupMenuItem(
        onTap: () => _onTapSortMenuItem(1, false),
        child: Row(
          children: [
            if (currentType == ItemSortMethod.createTime)
              const Icon(Icons.check, size: 20, color: Colors.blue)
            else
              const SizedBox(width: 20),
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 12),
            const Text('创建时间'),
          ],
        ),
      ),
      PopupMenuItem(
        onTap: () => _onTapSortMenuItem(2, false),
        child: Row(
          children: [
            if (currentType == ItemSortMethod.modifyTime)
              const Icon(Icons.check, size: 20, color: Colors.blue)
            else
              const SizedBox(width: 20),
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 12),
            const Text('修改时间'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      // 排序顺序
      PopupMenuItem(
        onTap: () => _onTapSortMenuItem(-1, true),
        child: Row(
          children: [
            if (isAscending)
              const Icon(Icons.check, size: 20, color: Colors.blue)
            else
              const SizedBox(width: 20),
            const Icon(Icons.arrow_upward, size: 20),
            const SizedBox(width: 12),
            const Text('升序'),
          ],
        ),
      ),
      PopupMenuItem(
        onTap: () => _onTapSortMenuItem(-1, false),
        child: Row(
          children: [
            if (!isAscending)
              const Icon(Icons.check, size: 20, color: Colors.blue)
            else
              const SizedBox(width: 20),
            const Icon(Icons.arrow_downward, size: 20),
            const SizedBox(width: 12),
            const Text('降序'),
          ],
        ),
      ),
    ];

    return items;
  }

  void _onTapSortMenuItem(int type, bool? ascending){
    final itemListService = ref.read(itemListServiceProvider);
    if (ascending != null) {
      if (type >= 0) {
        // 修改排序类型
        switch (type) {
          case 0:
            itemListService.setSortMethod(
                ItemSortMethod.name, ascending);
            break;
          case 1:
            itemListService.setSortMethod(
                ItemSortMethod.createTime, ascending);
            break;
          case 2:
            itemListService.setSortMethod(
                ItemSortMethod.modifyTime, ascending);
            break;
        }
      } else {
        // 修改排序顺序
        itemListService.setSortMethod(
            itemListService.getSortType(), ascending);
      }
      _loadItems();
    }
  }

  // 显示名称输入对话框
  Future<void> _showNameDialog({
    required String title,
    String? initialValue,
    String hintText = '请输入名称',
    required Function(String) onConfirm,
  }) async {
    String name = initialValue ?? '';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: initialValue),
          decoration: InputDecoration(hintText: hintText),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(name);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
