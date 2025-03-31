import 'dart:io';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kpasslib/kpasslib.dart';
import "../models/database_model.dart";
import '../models/unlock_params.dart';
import 'local_storage_service.dart';
import '../utils/keepass_utils.dart';

class KeePassFileService {
  static final _log = Logger('ImportKeePass');
  final LocalStorageService _localStorageService;

  // 通过构造函数注入依赖
  KeePassFileService({
    required LocalStorageService localStorageService,
  }) : _localStorageService = localStorageService;

  Future<void> tryOpenAllDatabase(OPRoot opData) async {
    opData.clear();
    for (var f in _localStorageService.databaseItems) {
      OPDatabase db = opData.getOrAddDatabase(f);
      if (f.password != null && f.password!.isNotEmpty) {
        final realPath = await _localStorageService.getDatabasePath(f.filePath, false);
        final kdbx = await compute<UnlockParams, KdbxDatabase?>(
          KeePassUtils.openKeePassFile,
          UnlockParams(
            filePath: realPath,
            password: f.password!,
            keyData: f.keyData,
          ),
        );
        if (kdbx != null) {
          db.dbInfo.name ??= kdbx.root.name;
          KeePassUtils.convertDatabase(opData, db, kdbx);
        }
      } else {
        _log.warning('${f.filePath} 没有密码，跳过');
      }
    }
    opData.rebuildAll();
  }

  // 先打开文件，如果密码正确，就把文件内容转换成OPDatabase
  Future<bool> tryAddKeePassFile(OPRoot opData, String filePath,
      String password, String? keyData, bool forceSavePassword) async {
    if (password.isNotEmpty) {
      final realPath = await _localStorageService.getDatabasePath(filePath, false);
      final kdbx = await compute<UnlockParams, KdbxDatabase?>(
        KeePassUtils.openKeePassFile,
        UnlockParams(
          filePath: realPath,
          password: password,
          keyData: keyData,
        ),
      );
      if (kdbx != null) {
        var f = await _localStorageService.updateDatabaseList(
            filePath, password, keyData, forceSavePassword, kdbx.root.name);
        OPDatabase db = opData.getOrAddDatabase(f);
        KeePassUtils.convertDatabase(opData, db, kdbx);
        opData.rebuildAll();
        return true;
      }
    } else {
      _log.warning('$filePath 没有密码，跳过');
    }
    return false;
  }

  // 先打开文件，如果密码正确，就把文件内容转换成OPDatabase
  Future<bool> importKeePassFile(OPDatabase targetDatabase, String filePath,
      String password, String? keyData) async {
    if (password.isEmpty) return false;
    final tarKdbx = targetDatabase.kdbx;
    if (tarKdbx==null) return false;

    final srcKdbx = await compute<UnlockParams, KdbxDatabase?>(
      KeePassUtils.openKeePassFile,
      UnlockParams(
        filePath: filePath,
        password: password,
        keyData: keyData,
      ),
    );
    if (srcKdbx == null) {
      return false;
    }

    // 复制
    _importKdbxGroup(tarKdbx, srcKdbx, srcKdbx.root, tarKdbx.root);
    return true;
  }

  void _importKdbxGroup(KdbxDatabase kdbx, KdbxDatabase from, KdbxGroup srcGroup, KdbxGroup parent) {
    for (var entry in srcGroup.entries) {
      kdbx.importEntry(entry: entry, target: parent, other: from);
    }

    for (var group in srcGroup.groups) {
      if (group!=from.recycleBin){
        final newGroup = KdbxGroup.copyFrom(group, KdbxUuid.random(
          prohibited: kdbx.root.allItems.map((e) => e.uuid).toSet()
        ));
        newGroup.parent = parent;
        parent.groups.add(newGroup);
        _importKdbxGroup(kdbx, from, group, newGroup);
      }
    }
  }

  Future<bool> createKeePassFile(OPRoot opData, String filePath, String name,
      String description, IconData icon, String password) async {
    try {
      final realPath = await _localStorageService.getDatabasePath(filePath, true);
      final kdbx = await compute<CreateParams, KdbxDatabase?>(
        KeePassUtils.createAndOpenKeePassFileImpl,
        CreateParams(
          filePath: realPath,
          name: name,
          description: description,
          icon: icon,
          password: password,
        ),
      );
      if (kdbx != null) {
        var f = await _localStorageService.updateDatabaseList(
            filePath, password, null, true, kdbx.root.name);
        OPDatabase db = opData.getOrAddDatabase(f);
        KeePassUtils.convertDatabase(opData, db, kdbx);
        opData.rebuildAll();
        return true;
      }
    } catch (e) {
      _log.warning('创建 KeePass 文件失败: $e');
    }
    return false;
  }

  Future<bool> deleteKeePassFile(String filePath) async {
    try {
      if (filePath.isEmpty ||
          filePath.length < 2 ||
          filePath.substring(0, 1) != '#') {
        return false;
      }
      final realPath = await _localStorageService.getDatabasePath(filePath, false);
      // 删除文件
      final file = File(realPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      _log.warning('删除文件失败: $e');
    }
    return false;
  }

  Future<List<String>> listLocalFiles() async {
    try {
      final dbPath = await _localStorageService.getDatabasePath("#/", true);
      final dbDir = Directory(dbPath);
      final files = await dbDir
          .list()
          .where((f) => f.path.toLowerCase().endsWith('.kdbx'))
          .toList();
      final rootDir = await _localStorageService.getDatabaseRoot();
      return files.map((f) => f.path.replaceAll(rootDir.path, '#')).toList();
    } catch (e) {
      return [];
    }
  }

  void onDatabaseChanged(OPDatabase db) {
    if (db.kdbx != null) {
      _saveKdbx(db);
    }
  }

  // 保存到文件中
  void _saveKdbx(OPDatabase db) async {
    print('Write DB: ${db.name}');
    final realPath = await _localStorageService.getDatabasePath(db.dbInfo.filePath, false);
    compute<WriteKdbxParams, void>(
      KeePassUtils.saveKeePassFile,
      WriteKdbxParams(
        filePath: realPath,
        db: db.kdbx as KdbxDatabase,
        password: db.dbInfo.password!, // 传入密码
        keyData: db.dbInfo.keyData, // 传入密钥文件数据
      ),
    );
  }

}
