import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../models/database_model.dart';
import '../models/edit_model.dart';
import '../models/database_info.dart';
import 'local_storage_service.dart';
import 'keepass_file_service.dart';

class QuickAccessEntry {
  final KdbxEntry entry;
  final String fieldName;

  QuickAccessEntry({
    required this.entry,
    required this.fieldName,
  });
}

enum ListViewType {
  allItem,
  byTag,
  byPath,
  byFavorite,
  byRecycleBin,
}

class ItemListService extends ChangeNotifier {

  bool isInitialized = false;
  int selectedView = 1;
  final KeePassFileService _keepassFileService;
  final LocalStorageService _localStorageService;
  final OPRoot opRoot;
  ListViewType _showType = ListViewType.allItem;
  String _showTag = "";
  OPDatabase? _showDb;
  KdbxGroup? recycleBinGroup;
  String _searchKeyword = "";
  List<KdbxItem> _allItems = [];
  List<KdbxItem> _showItems = [];
  ItemSortMethod _sortType = ItemSortMethod.modifyTime;
  bool _sortAscending = false;

  ItemListService({
    required KeePassFileService keepassImporter,
    required LocalStorageService localStorageService,
  }) : 
    _keepassFileService = keepassImporter,
    _localStorageService = localStorageService,
    opRoot = OPRoot(keepassFileService: keepassImporter) {
    // 初始化完成后设置回调函数
    setDatabaseModelCallbacks(
      getDatabaseByRoot: getDatabaseByRoot,
      getFolderName: getFolderName,
      getFolderIcon: getFolderIcon,
    );
  }

  // 当数据发生变化时，调用此方法通知所有监听者
  void notifyChanges() {
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    _showType = ListViewType.allItem;
    opRoot.clear();
    _allItems = [];
    _showItems = [];
    recycleBinGroup = null;
    _showDb = null;
    _searchKeyword = '';
    _sortType = ItemSortMethod.modifyTime;
    _sortAscending = false;
    isInitialized = false;
  }

  Future<void> openAllDatabase() async {
    // 模拟初始化数据
    if (!isInitialized) {
      isInitialized = true;
      await _keepassFileService.tryOpenAllDatabase(opRoot);
    }
  }

  bool isShowTree() {
    return _showType == ListViewType.byPath ||
        _showType == ListViewType.byRecycleBin;
  }

  ListViewType getShowType() {
    return _showType;
  }

  // 获取当前显示的数据库
  OPDatabase? getShowDatabase() {
    return _showDb;
  }

  // 获取当前显示的数据库
  OPDatabase getDatabaseByRoot(KdbxItem root) {
    for (var db in opRoot.allDatabases) {
      if (db.kdbx?.root == root) {
        return db;
      }
    }
    return opRoot.allDatabases[0];
  }

  // 获取当前显示的文件夹
  KdbxGroup? getShowFolder() {
    return opRoot.getFolder(_showDb!, _showDb!.lastFolderID);
  }

  // 获取当前显示的文件夹
  KdbxGroup? getShowFolderParent() {
    var f = opRoot.getFolder(_showDb!, _showDb!.lastFolderID);
    if (f != null) {
      return opRoot.getFolder(_showDb!, f.parent?.uuid.string ?? "");
    }
    return null;
  }

  // 获取文件夹名称
  String getShowFolderName() {
    if (_showType == ListViewType.byRecycleBin) {
      if (recycleBinGroup != null) {
        return recycleBinGroup!.name;
      } else {
        return "回收站";
      }
    } else if (_showType == ListViewType.byPath && _showDb != null) {
      var f = opRoot.getFolder(_showDb!, _showDb!.lastFolderID);
      if (f != null) {
        return f.name;
      } else {
        return "/";
      }
    }
    return "";
  }

  // 获取文件夹名称
  String getFolderName(KdbxGroup? folder) {
    if (folder == null) {
      if (_showType == ListViewType.byRecycleBin) {
        return getAllRecycleBinName();
      } else if (_showType == ListViewType.byPath && _showDb != null) {
        return _showDb!.name;
      } else {
        return getAllItemName();
      }
    }
    if (folder == folder.db.recycleBin) {
      return getRecycleBinName(folder);
    }
    if (folder == folder.db.root) {
      return folder.db.name;
    }
    return folder.name;
  }

  // 获取文件夹图标
  Widget getFolderIcon(KdbxGroup? folder, {double? size, Color? color}) {
    if (folder == null) {
      if (_showType == ListViewType.byRecycleBin) {
        return Icon(getAllRecycleBinIcon());
      } else if (_showDb != null) {
        return _showDb!.databaseIcon();
      } else {
        return Icon(getAllItemIcon());
      }
    }
    if (folder == folder.db.recycleBin) {
      return Icon(Icons.delete);
    }
    if (folder == folder.db.root) {
      return folder.db.databaseIcon();
    }
    return Icon(Icons.folder_outlined);
  }

  String getAllItemName() {
    return '所有项目';
  }

  String getAllRecycleBinName() {
    return '回收站';
  }

  String getRecycleBinName(KdbxGroup folder) {
    return '${folder.db.name} 的回收站';
  }

  IconData getAllItemIcon() {
    return Icons.list;
  }

  IconData getAllRecycleBinIcon() {
    return Icons.folder_delete;
  }

  int getFolderEntityCount(KdbxGroup folder) {
    int count = 0;
    for (var item in folder.children) {
      if (item is KdbxEntry) {
        count++;
      } else if (item is KdbxGroup) {
        count += getFolderEntityCount(item);
      }
    }
    return count;
  }

  int getCurrentFolderEntityCount() {
    if (_showType == ListViewType.byRecycleBin) {
      if (recycleBinGroup != null) {
        return getFolderEntityCount(recycleBinGroup!);
      } else {
        return opRoot.allRecycleBins.length;
      }
    } else if (_showType == ListViewType.byPath && _showDb != null) {
      var f = opRoot.getFolder(_showDb!, _showDb!.lastFolderID);
      if (f != null) {
        return getFolderEntityCount(f);
      } else {
        if (_showDb == null || _showDb!.kdbx == null) return 0;
        return getFolderEntityCount(_showDb!.kdbx!.root);
      }
    }
    return 0;
  }

  // 获取从当前目录开始的上层目录
  //   includeSelf 是否包含当前目录
  //   includeDB 是否包含数据库
  List<KdbxGroup> getParentFolders(bool includeSelf, bool includeDB) {
    List<KdbxGroup> parents = [];
    KdbxGroup? current = getCurrentFolder();
    if (current != null) {
      if (includeSelf) {
        parents.add(current);
      }
      while (current != null && current.parent != null) {
        parents.add(current.parent!);
        current = current.parent;
      }
      if (!includeDB) {
        parents.removeLast();
      }
    }
    return parents;
  }

  KdbxGroup? getCurrentFolder() {
    if (_showType == ListViewType.byRecycleBin) {
      if (recycleBinGroup != null) {
        return recycleBinGroup!;
      } else {
        return null;
      }
    } else if (_showType == ListViewType.byPath && _showDb != null) {
      var f = opRoot.getFolder(_showDb!, _showDb!.lastFolderID);
      if (f != null) {
        return f;
      } else {
        return null;
      }
    }
    return null;
  }

  String getShowTypeText() {
    switch (_showType) {
      case ListViewType.allItem:
        return getAllItemName();
      case ListViewType.byTag:
        return "标签: $_showTag";
      case ListViewType.byPath:
        return "${_showDb?.name}";
      case ListViewType.byFavorite:
        return "收藏";
      case ListViewType.byRecycleBin:
        return getAllRecycleBinName();
    }
  }

  void setSortMethod(ItemSortMethod type, bool ascending) {
    _sortType = type;
    _sortAscending = ascending;
    _refreshListItems(false, false, true);
  }

  ItemSortMethod getSortType() {
    return _sortType;
  }

  bool getSortAscending() {
    return _sortAscending;
  }

  Future<bool> addDatabase(String filePath, String password, String? keyData,
      bool forceSavePassword) async {
    return await _keepassFileService.tryAddKeePassFile(
        opRoot, filePath, password, keyData, forceSavePassword);
  }

  Future<bool> importKdbx(OPDatabase targetDatabase, String filePath, String password, String? keyData) async {
    bool ret = await _keepassFileService.importKeePassFile(
        targetDatabase, filePath, password, keyData);
    if (ret) {
      opRoot.rebuildAll();
      opRoot.onDatabaseChanged(targetDatabase);
    }
    return ret;
  }

  Future<bool> unlockDatabase(OPDatabase db, String password, String? keyData,
      bool forceSavePassword) async {
    return await _keepassFileService.tryAddKeePassFile(
        opRoot, db.dbInfo.filePath, password, keyData, forceSavePassword);
  }

  // 从数据中移除数据库
  Future<bool> removeDatabase(OPDatabase db, bool deleteFile) async {
    DatabaseInfo dbInfo = db.dbInfo;
    String filePath = dbInfo.filePath;
    opRoot.removeDatabase(db);
    await _localStorageService.deleteDatabaseList(dbInfo);
    if (deleteFile) {
      await _keepassFileService.deleteKeePassFile(filePath);
    }
    return true;
  }

  List<KdbxItem> getItems() {
    return _showItems;
  }

  List<KdbxEntry> getFavoriteItems() {
    List<KdbxEntry> favorites = [];
    for (var f in _localStorageService.favoriteIds) {
      OPDatabase? db = opRoot.findDatabaseById(f.dbId);
      if (db != null) {
        var entry = opRoot.findEntryById(db, f.itemId);
        if (entry != null) {
          favorites.add(entry);
        }
      }
    }
    return favorites;
  }

  List<KdbxEntry> getRecentSearchItems() {
    List<KdbxEntry> entries = [];
    for (var item in _localStorageService.recentSearches) {
      OPDatabase? db = opRoot.findDatabaseById(item.dbId);
      if (db != null) {
        var entry = opRoot.findEntryById(db, item.itemId);
        if (entry != null) {
          entries.add(entry);
        }
      }
    }
    return entries;
  }

  List<KdbxEntry> getRecentCreatedItems() {
    var allEntries = opRoot.getEntriesAll();
    if (allEntries.isEmpty) return [];

    // 使用优先队列找出前5个最新创建的条目
    return allEntries.cast<KdbxEntry>().fold<List<KdbxEntry>>(
      [],
      (list, entry) {
        if (list.length < 5) {
          list.add(entry);
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else if (entry.createdAt.compareTo(list.last.createdAt) > 0) {
          list.removeLast();
          list.add(entry);
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        return list;
      },
    );
  }

  void addRecentSearch(KdbxEntry entry) {
    _localStorageService.addRecentSearch(entry.db.dbid, entry.id);
  }

  void clearRecentSearch() {
    _localStorageService.clearRecentSearches();
  }

  List<QuickAccessEntry> getQuickAccessItems() {
    List<QuickAccessEntry> ret = [];
    for (var f in _localStorageService.quickAccessItems) {
      OPDatabase? db = opRoot.findDatabaseById(f.dbId);
      if (db != null) {
        var entry = opRoot.findEntryById(db, f.itemId);
        if (entry != null) {
          // 查找对应的字段
          String fieldName = '';
          for (var key in entry.fields.keys) {
            if (key == f.fieldName) {
              fieldName = key;
              break;
            }
          }
          // for (var group in entry.groups) {
          //   for (var field in group.fields) {
          //     if (field.name == f.fieldName) {
          //       fieldName = field.name;
          //       break;
          //     }
          //   }
          //   if (fieldName.isNotEmpty) break;
          // }
          if (fieldName.isNotEmpty) {
            ret.add(QuickAccessEntry(
              entry: entry,
              fieldName: fieldName,
            ));
          }
        }
      }
    }
    return ret;
  }

  Future<bool> addEntry(EditEntry editEntry) async {
    // 往数据库中添加实体
    // if (db.kdbx == null) return false;
    // var kdbx = db.kdbx!;
    if (editEntry.parent == null) return false;
    var parent = editEntry.parent;
    var db = parent!.db;
    if (db.kdbx == null) return false;
    var kdbxEntry = db.kdbx!.createEntry(parent: parent);
    kdbxEntry.times = KdbxTimes.fromTime(DateTime.now());

    // 设置值
    editEntry.toDbEntry(kdbxEntry);

    opRoot.onEntryAdded(kdbxEntry);
    _refreshListItems(true, false, false);
    return true;
  }

  Future<bool> deleteEntry(KdbxEntry entry, bool mayMoveToRecycle) async {
    var db = entry.db;
    if (db.kdbx == null) return false;
    var kdbx = db.kdbx!;
    if (mayMoveToRecycle) {
      kdbx.remove(entry);
    } else {
      kdbx.move(item: entry, target: null);
    }
    opRoot.onEntryDelete(db);
    _refreshListItems(true, false, false);
    return true;
  }

  Future<bool> recoverEntry(KdbxEntry entry) async {
    var db = entry.db;
    if (db.kdbx == null) return false;
    var kdbx = db.kdbx!;
    KdbxGroup parent = kdbx.getGroup(uuid: entry.previousParent) ?? kdbx.root;
    kdbx.move(item: entry, target: parent);
    opRoot.onEntryChanged(db, entry);
    _refreshListItems(true, false, false);
    return true;
  }

  Future<void> onEntryChanged(KdbxEntry entry) async {
    opRoot.onEntryChanged(entry.db, entry);
    _refreshListItems(true, false, false);
  }

  void createFolder(String name) {
    if (_showType == ListViewType.byPath && _showDb != null) {
      if (_showDb!.kdbx != null) {
        var kdbx = _showDb!.kdbx!;
        var parent = getCurrentFolder() ?? kdbx.root;
        var kdbxGroup = kdbx.createGroup(parent: parent, name: name);

        opRoot.onFolderAdded(_showDb!, kdbxGroup);

        _refreshListItems(true, false, false);
      }
    }
  }

  void renameCurrentFolder(String newName) {
    if (_showType == ListViewType.byPath && _showDb != null) {
      if (_showDb!.kdbx != null) {
        var kdbxFolder = getCurrentFolder();
        if (kdbxFolder != null) {
          kdbxFolder.name = newName;
          opRoot.onFolderChanged(_showDb!, kdbxFolder);
          _refreshListItems(true, false, false);
        }
      }
    }
  }

  void moveCurrentFolderTo(KdbxGroup? target) {
    if (target == null) return;
    var current = getCurrentFolder();
    if (current == null || current == target) return;
    if (current.parent == target) return;
    if (_showDb == null || _showDb!.kdbx == null) return;
    var kdbx = _showDb!.kdbx!;
    kdbx.move(item: current, target: target);
  }

  void deleteCurrentFolder() {
    if (_showDb != null) {
      if (_showDb!.kdbx != null) {
        var kdbx = _showDb!.kdbx!;
        var kdbxFolder = getCurrentFolder();
        if (kdbxFolder != null && kdbxFolder != kdbx.root) {

          if (_showType==ListViewType.byRecycleBin && recycleBinGroup==kdbxFolder){
            recycleBinGroup = kdbxFolder.parent?? kdbx.recycleBin;
          }

          var parnetID = kdbxFolder.parent?.uuid.string ?? '';
          if (_showType == ListViewType.byPath){
            // 普通删除
            kdbx.remove(kdbxFolder);
          }else if (_showType == ListViewType.byRecycleBin){
            // 彻底删除
            kdbx.move(item: kdbxFolder, target: null);
          }
          opRoot.onFolderDeleted(_showDb!);
          _showDb!.lastFolderID = parnetID;
          
          _refreshListItems(true, false, false);
        }
      }
    }
  }

  void recoverCurrentFolder() {
    if (_showType == ListViewType.byRecycleBin && _showDb != null) {
      if (_showDb!.kdbx != null) {
        var kdbx = _showDb!.kdbx!;
        var kdbxFolder = getCurrentFolder();
        if (kdbxFolder != null && kdbxFolder != kdbx.root) {

          if (_showType==ListViewType.byRecycleBin && recycleBinGroup==kdbxFolder){
            recycleBinGroup = kdbxFolder.parent?? kdbx.recycleBin;
          }

          var group = kdbx.getGroup(uuid: kdbxFolder.previousParent);
          if (group!=null && group.isInRecycleBin) {
            group = null;
          }
          KdbxGroup parent = group ?? kdbx.root;
          kdbx.move(item: kdbxFolder, target: parent);
          opRoot.onFolderDeleted(_showDb!);
          _refreshListItems(true, false, false);
        }
      }
    }
  }

  // 全部项目
  void setItemListAll() {
    _showType = ListViewType.allItem;
    _showDb = null;
    _refreshListItems(true, false, false);
  }

  void setItemListByFavorites() {
    _showType = ListViewType.byFavorite;
    _showDb = null;
    _refreshListItems(true, false, false);
  }

  void setItemListByTag(String tag) {
    _showType = ListViewType.byTag;
    _showTag = tag;
    _showDb = null;
    _refreshListItems(true, false, false);
  }

  void setItemListByDatabase(OPDatabase db) {
    _showType = ListViewType.byPath;
    _showDb = db;
    _refreshListItems(true, false, false);
  }

  void setItemListByRecycleBin(KdbxGroup? folder) {
    _showType = ListViewType.byRecycleBin;
    recycleBinGroup = folder;
    _refreshListItems(true, false, false);
  }

  void setItemListByFolder(KdbxGroup? folder) {
    if (_showType == ListViewType.byRecycleBin) {
      setItemListByRecycleBin(folder);
    } else if (_showType == ListViewType.byPath) {
      if (folder != null) {
        if (_showDb != folder.db) {
          _showDb = folder.db;
        }
        if (folder != folder.root) {
          _showDb!.lastFolderID = folder.id;
        } else {
          _showDb!.lastFolderID = "";
        }
      } else {
        _showDb!.lastFolderID = "";
      }
      _refreshListItems(true, false, false);
    }
  }

  // 根据文件夹ID导航到指定文件夹
  void setItemListByFolderId(String folderId) {
    if (_showDb == null || _showDb!.kdbx == null) return;
    if (_showType == ListViewType.byRecycleBin ||
        _showType == ListViewType.byPath) {
      var kdbx = _showDb!.kdbx!;
      var f = kdbx.getGroup(uuid: KdbxUuid.fromString(folderId));
      setItemListByFolder(f);
    }
  }

  void search(String keyword) {
    if (_searchKeyword == keyword.toLowerCase()) {
      return;
    }
    _searchKeyword = keyword.toLowerCase();
    _refreshListItems(false, true, false);
  }

  bool isTopFolder() {
    if (_showType == ListViewType.byRecycleBin) {
      return (recycleBinGroup==null);
    } else if (_showType == ListViewType.byPath) {
      if (_showDb != null) {
        var f = getCurrentFolder();
        if (f != null) {
          return f.parent==null;
        }
      }
    }
    return true;
  }

  bool setItemListUpFolder() {
    if (_showType == ListViewType.byRecycleBin) {
      if (recycleBinGroup != null) {
        recycleBinGroup = recycleBinGroup!.parent;
        if (recycleBinGroup != null &&
            recycleBinGroup == recycleBinGroup!.db.root) {
          recycleBinGroup = null;
        }
        _refreshListItems(true, false, false);
        return true;
      }
    } else if (_showType == ListViewType.byPath) {
      if (_showDb != null) {
        var f = getCurrentFolder();
        if (f != null) {
          _showDb!.lastFolderID = (f.parent?.uuid.string) ?? '';
          _refreshListItems(true, false, false);
          return true;
        }
      }
    }
    return false;
  }

  void _refreshListItems(
      bool refreshItems, bool refreshKeyword, bool refreshSort) {
    // 获取列表
    if (refreshItems) {
      refreshKeyword = true;
      switch (_showType) {
        case ListViewType.allItem:
          _allItems = opRoot.getEntriesAll();
          break;
        case ListViewType.byTag:
          _allItems = opRoot.getEntriesByTag(_showTag);
          break;
        case ListViewType.byPath:
          _allItems = opRoot.getItemsByPath(_showDb, _showDb!.lastFolderID);
          break;
        case ListViewType.byFavorite:
          _allItems = getFavoriteItems();
          break;
        case ListViewType.byRecycleBin:
          _allItems = opRoot.getRecycleBinItems(recycleBinGroup);
          break;
      }
    }
    // 关键词过滤
    if (refreshKeyword) {
      refreshSort = true;
      if (_searchKeyword.isNotEmpty) {
        _showItems = _allItems.where((item) {
          if (item is KdbxEntry) {
            for (var key in item.fields.keys) {
              final val = item.fields[key];
              if (val == null || val is ProtectedTextField) {
                continue;
              }
              if (key.toLowerCase().contains(_searchKeyword) ||
                  val.text.toLowerCase().contains(_searchKeyword)) {
                return true;
              }
            }
          } else if (item is KdbxGroup) {
            // 搜索文件夹名称
            return item.name.toLowerCase().contains(_searchKeyword);
          }
          return false;
        }).toList();
      } else {
        _showItems = _allItems;
      }
    }

    if (refreshSort) {
      _showItems.sort((a, b) {
        // 首先按类型排序：文件夹在前，实体在后
        if (a is KdbxGroup && b is KdbxEntry) return -1;
        if (a is KdbxEntry && b is KdbxGroup) return 1;

        int result;
        switch (_sortType) {
          case ItemSortMethod.modifyTime:
            result = a.modifiedAt.compareTo(b.modifiedAt);
            break;
          case ItemSortMethod.createTime:
            result = a.createdAt.compareTo(b.createdAt);
            break;
          case ItemSortMethod.name:
            result = a.name.compareTo(b.name);
            break;
        }
        return _sortAscending ? result : -result;
      });
    }
    notifyChanges();
  }
}
