import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';

class FolderSelectPage extends ConsumerStatefulWidget {
  final OPDatabase? initialDb;
  final String? initialFolderId; // 初始文件夹ID
  final bool allowRoot; // 是否允许选择根目录

  const FolderSelectPage({
    super.key,
    this.initialDb,
    this.initialFolderId,
    this.allowRoot = true,
  });

  @override
  ConsumerState<FolderSelectPage> createState() => _FolderSelectPageState();
}

class _FolderSelectPageState extends ConsumerState<FolderSelectPage> {
  List<dynamic> _items = []; // dynamic is KdbxGroup or OPDatabase
  final GlobalKey _folderButtonKey = GlobalKey();
  OPDatabase? selectedDb;
  KdbxGroup? selectedFolder;

  @override
  void initState() {
    super.initState();
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
      final items = selectedFolder!.groups;
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
      if (selectedFolder != null && selectedFolder != selectedDb!.kdbx!.root) {
        selectedFolder = selectedFolder!.parent;
      } else {
        selectedFolder = null;
      }
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentName = selectedFolder?.name ?? '全部保险库';
    String parentName = '返回';
    if (selectedFolder != null) {
      if (selectedFolder!.parent != null) {
        parentName = selectedFolder!.parent!.name;
      } else {
        parentName = '全部保险库';
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Row(
            children: [
              const Icon(Icons.arrow_back_ios, size: 18),
              Expanded(
                child: Text(
                  parentName,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          onPressed: _moveUp,
        ),
        leadingWidth: 120, // 调整左侧宽度

        title: selectedFolder != null
            ? InkWell(
                key: _folderButtonKey,
                onTap: () => _showFolderMenu(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            : Text(
                currentName,
                overflow: TextOverflow.ellipsis,
              ),
        centerTitle: true,

        actions: [
          if (selectedDb != null || widget.allowRoot)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context, selectedFolder);
                },
                child: const Text('选择'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
    String name = 'Error';
    String desc = 'Error';
    IconData iconData = Icons.folder;
    if (folder is OPDatabase) {
      name = folder.name;
      desc = '${folder.kdbx!.root.children.length}';
      iconData = Icons.lock_outline;
    } else if (folder is KdbxGroup) {
      name = folder.name;
      desc = '${folder.children.length}';
      iconData = Icons.folder;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, color: Colors.blue),
      ),
      title: Text(name),
      subtitle: Text(
        desc,
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (folder is OPDatabase) {
          selectedDb = folder;
          selectedFolder = folder.kdbx!.root;
        } else if (folder is KdbxGroup) {
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
    parentFolders.add(null);

    showMenu<String>(
      context: context,
      position: position,
      items: [
        if (parentFolders.isNotEmpty)
          ...parentFolders.map((folder) => PopupMenuItem<String>(
                value: folder?.uuid.string ?? 'root',
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Text(folder == null ? '全部保险库' : folder.name),
                  ],
                ),
              )),
      ],
    ).then((value) {
      if (value != null) {
        if (value != 'root' && selectedDb != null) {
          var root = selectedDb!.kdbx!.root;
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
