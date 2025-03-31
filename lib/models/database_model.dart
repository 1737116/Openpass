import 'dart:io';
import 'package:collection/collection.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter/material.dart';
import 'package:openpass_cloud/widgets/vault_icon_widget.dart';
import 'database_info.dart';
import '../services/keepass_file_service.dart';

// 名字，创建时间，修改时间
enum ItemSortMethod {
  name,
  createTime,
  modifyTime,
}

typedef GetDatabaseByRootCallback = OPDatabase Function(KdbxItem root);
typedef GetFolderNameCallback = String Function(KdbxGroup folder);
typedef GetFolderIconCallback = Widget Function(KdbxGroup folder,{double? size, Color? color});

// 全局回调函数，可以通过依赖注入设置
GetDatabaseByRootCallback? _getDatabaseByRootCallback;
GetFolderNameCallback? _getFolderNameCallback;
GetFolderIconCallback? _getFolderIconCallback;

// 设置回调函数的方法
void setDatabaseModelCallbacks({
  required GetDatabaseByRootCallback getDatabaseByRoot,
  required GetFolderNameCallback getFolderName,
  required GetFolderIconCallback getFolderIcon,
}) {
  _getDatabaseByRootCallback = getDatabaseByRoot;
  _getFolderNameCallback = getFolderName;
  _getFolderIconCallback = getFolderIcon;
}


extension KdbxItemExtension on KdbxItem {
  KdbxItem get root {
    KdbxItem current = this;
    while (current.parent != null) {
      current = current.parent!;
    }
    return current;
  }

  OPDatabase get db {
    if (_getDatabaseByRootCallback == null) {
      throw Exception('getDatabaseByRoot callback not set');
    }
    return _getDatabaseByRootCallback!(root);
  }

  String get id => uuid.string;
  String get name {
    if (this is KdbxGroup) {
      return (this as KdbxGroup).name;
    } else if (this is KdbxEntry) {
      return (this as KdbxEntry).fields['Title']!.text;
    }
    return '';
  }

  DateTime get modifiedAt => times.modification.timeOrZero;
  DateTime get createdAt => times.creation.timeOrZero;
  DateTime get expiredAt => times.expiry.timeOrZero;
  
  bool get isInRecycleBin {
    var recycleBin = db.recycleBin;
    KdbxGroup? parent = this.parent;
    while (parent!= null) {
      if (parent.uuid == recycleBin?.uuid) {
        return true;
      }
      parent = parent.parent;
    }
    return false;
  }
}

extension KdbxEntryExtension on KdbxEntry {
  String getUsername() {
    return (fields['UserName']?.text) ?? "";
  }

  Color getBackground() {
    // return (entry.fields['UserName']?.text)??"";
    return Colors.grey;
  }

  KdbxTextField? getValue(String key) {
    return fields[key];
  }
  
  String? getString(String key) {
    return fields[key]?.text;
  }

  String? getCustomValue(String key) {
    if (customData != null) {
      if (customData!.map.containsKey(key)) {
        return customData!.map[key]!.value;
      }
    }
    return null;
  }
  
  bool setCustomValue(String key, String? val) {
    if (val != null && val.isEmpty) {
      val = null;
    }

    if (getCustomValue(key) == val) {
      return false;
    }

    if (val == null) {
      if (customData != null) {
        customData!.map.remove(key);
      }
    } else {
      customData ??= KdbxCustomData();
      customData!.map[key] = KdbxCustomItem(value: val);
    }
    // print('$key = $val');
    return true;
  }
}

extension KdbxGroupExtension on KdbxGroup {
  String get dbName => db.name;
  Widget dbIcon({double? size, Color? color}) => db.databaseIcon(size:size);

  String get folderName {
    if (_getFolderNameCallback == null) {
      throw Exception('getFolderName callback not set');
    }
    return db.kdbx?.root == this ? '/' : _getFolderNameCallback!(this);
  }
  
  Widget folderIcon({double? size, Color? color}) {
    if (_getFolderIconCallback == null) {
      throw Exception('getFolderIcon callback not set');
    }
    return db.kdbx?.root == this
      ? Icon(Icons.folder_outlined, size:size, color:color)
      : _getFolderIconCallback!(this, size:size, color:color);
  }

  String get folderOrDbName => db.kdbx?.root == this ? dbName : folderName;
  Widget folderOrDbIcon({double? size, Color? color}) {
    if (db.kdbx?.root == this) {
      return dbIcon(size:size, color:color);
    }
    return folderIcon(size:size, color:color);
  } 

}

class OPDatabase {
  DatabaseInfo dbInfo;
  bool isUnlocked = false;
  bool isReadonly = true;
  KdbxDatabase? kdbx;
  String lastFolderID = "";
  bool isDirty = false;

  OPDatabase({
    required this.dbInfo,
  });

  String get dbid => dbInfo.id;
  KdbxGroup get root => kdbx!.root;
  KdbxGroup? get recycleBin => kdbx?.recycleBin;
  KdbxGroup get lastFolder => kdbx!.getGroup(uuid: KdbxUuid.fromString(lastFolderID))??kdbx!.root;
  KdbxGroup get parentFolder => kdbx!.recycleBin!;

  String get name {
    if (dbInfo.name != null) {
      return dbInfo.name!;
    }
    final fileName = dbInfo.filePath.split(Platform.pathSeparator).last;
    final lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex > 0 ? fileName.substring(0, lastDotIndex) : fileName;
  }

  Widget databaseIcon({double? size}) {
    return VaultIconWidget(iconName: dbInfo.dbIcon??'', size: size??24);
  }
  String getDatabaseIcon() {
    return dbInfo.dbIcon??'';
  }
  void setDatabaseIcon(String iconName) {
    dbInfo.dbIcon = iconName.isEmpty?null: iconName;
  }

}

class OPRoot {
  final List<OPDatabase> _allDatabases = [];
  final Map<String, OPDatabase> _mapDatabases = {};
  final List<KdbxEntry> _allEntries = [];
  final List<KdbxGroup> _allFolders = [];
  final List<KdbxGroup> _allRecycleBins = [];
  final Set<String> _allTags = {};

  final KeePassFileService _keepassFileService;

  OPRoot({required KeePassFileService keepassFileService}) 
      : _keepassFileService = keepassFileService;

  List<OPDatabase> get allDatabases => List.unmodifiable(_allDatabases);
  List<KdbxGroup> get allRecycleBins => List.unmodifiable(_allRecycleBins);
  Set<String> get allTags => Set.unmodifiable(_allTags);

  OPDatabase? findDatabaseById(String dbid) {
    return _mapDatabases[dbid];
  }

  OPDatabase? findDatabaseByPath(String filePath) {
    return _allDatabases
        .where((db) => db.dbInfo.filePath == filePath)
        .firstOrNull;
  }

  KdbxGroup? getDefaultAddEntryFolder() {
    for (var db in _allDatabases) {
      if (db.isUnlocked) {
        return db.lastFolder;
      }
    }
    return null;
  }

  KdbxEntry? findEntryById(OPDatabase db, String id) {
    return _allEntries.firstWhereOrNull((e) => e.db == db && e.id == id);
  }

  KdbxGroup? getFolder(OPDatabase db, String id) {
    return _allFolders.firstWhereOrNull((e) => e.db == db && e.id == id);
  }

  KdbxGroup? findFolder(OPDatabase db, List<String> path) {
    KdbxGroup? current = db.kdbx?.root;
    if (path.isEmpty) return current; // 根目录
    // 从根目录开始逐级查找
    for (String name in path) {
      final folders = current?.children.whereType<KdbxGroup>();
      if (folders == null) return null;
      current = folders.where((f) => f.name == name).firstOrNull;
      if (current == null) return null; // 路径中任何一级不存在，返回 null
    }
    return current;
  }

  List<KdbxItem> getItemsByPath(OPDatabase? db, String folderId) {
    if (db == null || db.kdbx == null) {
      return _allEntries;
    }

    // 找到目标文件夹
    var kdbx = db.kdbx!;
    var p = getFolder(db, folderId);
    KdbxGroup targetFolder = (p == null) ? kdbx.root : p;

    // 转成列表
    List<KdbxItem> items = [];
    for (var item in targetFolder.children) {
      if (item is KdbxEntry) {
        items.add(item);
      } else if (item is KdbxGroup) {
        if (item.uuid == kdbx.meta.recycleBinUuid) {
          continue;
        }
        items.add(item);
      }
    }
    return items;
  }

  List<KdbxItem> getRecycleBinItems(KdbxGroup? folder) {
    if (folder == null) {
      // 全部回收站
      return _allRecycleBins;
    }

    // 转成列表
    var db = folder.db;
    var kdbx = db.kdbx!;
    List<KdbxItem> items = [];
    for (var item in folder.children) {
      if (item is KdbxEntry) {
        items.add(item);
      } else if (item is KdbxGroup) {
        if (item.uuid == kdbx.meta.recycleBinUuid) {
          continue;
        }
        items.add(item);
      }
    }
    return items;
  }

  void clear() {
    _allDatabases.clear();
    _mapDatabases.clear();
    _allEntries.clear();
    _allFolders.clear();
    _allRecycleBins.clear();
    _allTags.clear();
  }

  void rebuildAll() {
    _allEntries.clear();
    _allFolders.clear();
    _allRecycleBins.clear();
    _allTags.clear();

    for (var db in _allDatabases) {
      if (db.isUnlocked && db.kdbx != null) {
        var kdbx = db.kdbx!;
        // 遍历根目录，把非回收站的文件夹和条目加入
        for (var i in kdbx.root.children) {
          if (i is KdbxEntry) {
            _allEntries.add(i);
          } else if (i is KdbxGroup) {
            if (i.uuid == kdbx.meta.recycleBinUuid) {
              _allRecycleBins.add(i);
            } else {
              _allFolders.add(i);
              for (var j in i.allEntries) {
                _allEntries.add(j);
              }
              for (var j in i.allGroups) {
                _allFolders.add(j);
              }
            }
          }
        }
      }
    }
    for (var i in _allEntries) {
      if (i.tags != null) {
        _allTags.addAll(i.tags!);
      }
    }
  }

  OPDatabase getOrAddDatabase(DatabaseInfo dbInfo) {
    for (var db in _allDatabases) {
      if (db.dbInfo == dbInfo) {
        return db;
      }
    }
    var db = OPDatabase(dbInfo: dbInfo);
    _allDatabases.add(db);
    _mapDatabases[db.dbid] = db;
    return db;
  }

  void removeDatabase(OPDatabase db) {
    // 删除数据库
    _allDatabases.remove(db);
    _mapDatabases.remove(db.dbid);
    rebuildAll();
  }

  List<KdbxEntry> getEntriesAll() {
    return _allEntries;
  }

  List<KdbxEntry> getEntriesByTag(String tag) {
    return _allEntries.where((e) => e.tags?.contains(tag) ?? false).toList();
  }

  // 当条目发生变化，尝试更新到kdbx
  void onEntryAdded(KdbxEntry entry) {
    _allEntries.add(entry);
    _allTags.addAll(entry.tags?? []);
    onDatabaseChanged(entry.db);
  }

  void onEntryDelete(OPDatabase db) {
    rebuildAll();
    onDatabaseChanged(db);
  }

  void onEntryChanged(OPDatabase db, KdbxEntry entry) {
    _allTags.addAll(entry.tags??[]);
    onDatabaseChanged(db);
  }

  void onFolderAdded(OPDatabase db, KdbxGroup folder) {
    _allFolders.add(folder);
    onDatabaseChanged(db);
  }

  void onFolderDeleted(OPDatabase db) {
    rebuildAll();
    onDatabaseChanged(db);
  }

  void onFolderChanged(OPDatabase db, KdbxGroup folder) {
    onDatabaseChanged(db);
  }

  void onDatabaseChanged(OPDatabase db) {
    db.isDirty = true;
    _keepassFileService.onDatabaseChanged(db);
  }
}
