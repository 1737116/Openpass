import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';

class FolderSelectSheet extends ConsumerStatefulWidget {
  final KdbxGroup? initialFolder;
  final KdbxGroup? excludeFolder;
  final bool allowRoot;

  const FolderSelectSheet({
    super.key,
    this.initialFolder,
    this.excludeFolder,
    this.allowRoot = false,
  });

  static Future<KdbxGroup?> show(
    BuildContext context, {
    KdbxGroup? initialFolder,
    KdbxGroup? excludeFolder,
    bool allowRoot = false,
  }) {
    final layoutService = ProviderScope.containerOf(context).read(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;

    if (isMobileLayout) {
      return showModalBottomSheet<KdbxGroup?>(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => FolderSelectSheet(
            initialFolder: initialFolder,
            excludeFolder: excludeFolder,
            allowRoot: allowRoot,
          ),
        ),
      );
    }else{
      // 桌面布局使用 Dialog
      return showDialog<KdbxGroup?>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(16),
            child: FolderSelectSheet(
              initialFolder: initialFolder,
              excludeFolder: excludeFolder,
              allowRoot: allowRoot,
            ),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<FolderSelectSheet> createState() => _FolderSelectSheetState();
}

class _FolderSelectSheetState extends ConsumerState<FolderSelectSheet> {
  List<dynamic> _items = []; // dynamic is KdbxGroup or OPDatabase
  final GlobalKey _folderButtonKey = GlobalKey();
  KdbxGroup? selectedFolder;

  @override
  void initState() {
    super.initState();
    // if (widget.initialDb != null && widget.initialDb!.kdbx != null) {
    //   selectedDb = widget.initialDb;
    // }
    if (widget.initialFolder != null) {
      selectedFolder = widget.initialFolder;
    }
    // 如果选择的是排除的文件夹，则返回上一级
    if (selectedFolder == widget.excludeFolder) {
      selectedFolder = widget.excludeFolder?.parent;
    }
    _loadItems();
  }

  Future<void> _loadItems() async {
    final itemListService = ref.read(itemListServiceProvider);
    if (selectedFolder == null) {
      // 列出所有数据库
      final items = itemListService.opRoot.allDatabases;
      setState(() {
        _items = items;
      });
    } else {
      var items = [];
      KdbxGroup? recycleBin;
      // 排除掉回收站
      if (selectedFolder != null) {
        recycleBin = selectedFolder!.db.kdbx!.recycleBin;
      }
      for (var g in selectedFolder!.groups) {
        if (g != recycleBin) {
          items.add(g);
        }
      }
      setState(() {
        _items = items;
      });
    }
  }

  void _moveUp() {
    if (selectedFolder == null) {
      selectedFolder = null;
      Navigator.pop(context);
    } else {
      if (selectedFolder != selectedFolder!.db.kdbx!.root) {
        selectedFolder = selectedFolder!.parent;
      } else if (widget.allowRoot) {
        selectedFolder = null;
      } else {
        Navigator.pop(context);
        return;
      }
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentName = selectedFolder?.folderOrDbName ?? '全部保险库';
    var currentIcon =
        selectedFolder == null ? Icon(Icons.list) : selectedFolder!.folderOrDbIcon();
    String parentName = '返回';
    bool isRoot;
    if (selectedFolder != null) {
      isRoot = false;
      if (selectedFolder!.parent != null) {
        parentName = selectedFolder!.parent!.name;
      } else if (widget.allowRoot) {
        parentName = '全部保险库';
      } else {
        isRoot = true;
      }
    } else {
      isRoot = true;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部拖动条
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    label: Text(
                      parentName,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _moveUp,
                  ),
                ),
                // if (selectedFolder != null) IconButton(
                //   icon: const Icon(Icons.arrow_back_ios, size: 18),
                //   onPressed: _moveUp,
                // ),
                Expanded(
                  child: Center(
                    child: isRoot == false
                        ? InkWell(
                            key: _folderButtonKey,
                            onTap: () => _showFolderMenu(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                currentIcon,
                                Flexible(
                                  child: Text(
                                    currentName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              currentIcon,
                              Text(
                                currentName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, selectedFolder);
                        },
                        child: const Text('选择'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(left: 60.0, right: 10.0),
                child: Divider(height: 1, color: Color(0xFFEEEEEE)),
              ),
              itemBuilder: (context, index) {
                return _buildFolderItem(context, _items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(BuildContext context, dynamic folder) {
    final itemListService = ref.read(itemListServiceProvider);
    String name = 'Error';
    String desc = 'Error';
    Widget icon = Icon(Icons.folder);
    if (folder is OPDatabase) {
      var db = folder;
      name = db.name;
      desc = db.kdbx == null ? '未解锁' : '${db.kdbx!.root.children.length}';
      icon = db.databaseIcon();
    } else if (folder is KdbxGroup) {
      name = itemListService.getFolderName(folder);
      desc = '${folder.children.length}';
      icon = itemListService.getFolderIcon(folder);
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: icon,
      ),
      title: Text(name),
      subtitle: Text(
        desc,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right),
      tileColor: (folder == widget.excludeFolder) ? Colors.grey[200] : null,
      onTap: () {
        if (folder is OPDatabase) {
          if (folder.kdbx != null) {
            selectedFolder = folder.kdbx!.root;
          }
        } else if (folder is KdbxGroup) {
          if (folder == widget.excludeFolder) {
            return;
          }
          selectedFolder = folder;
        }
        _loadItems();
      },
    );
  }

  void _showFolderMenu(BuildContext context) {
    final RenderBox? button =
        _folderButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + button.size.height,
      buttonPosition.dx + button.size.width,
      buttonPosition.dy + button.size.height,
    );

    final List<KdbxGroup?> parentFolders = [];
    if (selectedFolder != null) {
      KdbxGroup? parent = selectedFolder!.parent;
      while (parent != null) {
        parentFolders.add(parent);
        parent = parent.parent;
      }
    }
    if (widget.allowRoot) {
      parentFolders.add(null);
    }

    showMenu<String>(
      context: context,
      position: position,
      items: [
        if (parentFolders.isNotEmpty)
          ...parentFolders.map((folder) => PopupMenuItem<String>(
                value: folder?.uuid.string ?? 'root',
                child: Row(
                  children: [
                    folder == null
                      ? Icon(Icons.folder_outlined, size:20, color:Colors.blue)
                      : folder.folderOrDbIcon(size:20, color:Colors.blue),
                    const SizedBox(width: 12),
                    Text(folder == null ? '全部保险库' : folder.folderOrDbName),
                  ],
                ),
              )),
      ],
    ).then((value) {
      if (value != null) {
        if (value != 'root') {
          var root = selectedFolder!.db.kdbx!.root;
          if (value == root.uuid.string) {
            selectedFolder = root;
          } else {
            selectedFolder =
                root.allGroups.firstWhereOrNull((g) => g.uuid.string == value);
          }
        } else {
          selectedFolder = null;
        }
        _loadItems();
      }
    });
  }
}
