import 'dart:io';
// import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import "../models/database_model.dart";
import '../models/unlock_params.dart';


class CreateParams {
  final String filePath;
  final String name;
  final String description;
  final IconData icon;
  final String password;

  CreateParams({
    required this.filePath,
    required this.name,
    required this.description,
    required this.icon,
    required this.password,
  });
}

class WriteKdbxParams {
  final String filePath;
  final KdbxDatabase db;
  final String password;
  final String? keyData;

  WriteKdbxParams({
    required this.filePath,
    required this.db,
    required this.password,
    this.keyData,
  });
}

class KeePassUtils {
  // static final Logger _log = Logger('KeePassUtils');

  // 写入文件
  static Future<void> saveKeePassFile(WriteKdbxParams params) async {
    try {
      // // 重新设置凭据
      // params.db.header.credentials = KdbxCredentials(
      //   password: ProtectedData.fromString(params.password),
      //   keyData: params.keyData?.codeUnits,
      // );

      final bytes = await params.db.save();

      // final credentials = KdbxCredentials(
      //   password: ProtectedData.fromString(params.password),
      //   keyData: params.keyData?.codeUnits,
      // );

      // final newDB = await KdbxDatabase.fromBytes(
      //   data: bytes,
      //   credentials: credentials,
      // );

      final file = File(params.filePath);
      file.writeAsBytesSync(bytes);
    } catch (e) {
      final logX = Logger('KeePassImport');
      logX.warning('保存 KeePass 文件失败: $e');
    }
  }

  static Future<KdbxDatabase?> openKeePassFile(UnlockParams params) async {
    try {
      // 读取文件
      final file = File(params.filePath);
      final bytes = file.readAsBytesSync();

      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(params.password),
        keyData: params.keyData?.codeUnits,
        // challengeResponse: challengeResponse,
      );

      return KdbxDatabase.fromBytes(
        data: bytes,
        credentials: credentials,
      );
    } catch (e) {
      final logX = Logger('KeePassImport');
      logX.warning('打开 KeePass 文件失败: $e');
      return null;
    }
  }

  static void convertDatabase(
      OPRoot opData, OPDatabase db, KdbxDatabase kdbx) {
    var path = db.dbInfo.filePath;
    db.isUnlocked = true;
    db.isReadonly = !(path.isNotEmpty && path[0] == '#');
    db.kdbx = kdbx;
  }

  static Future<KdbxDatabase?> createAndOpenKeePassFileImpl(
      CreateParams params) async {
    if (!await createKeePassFileImpl(params)) return null;
    return await openKeePassFile(UnlockParams(
      filePath: params.filePath,
      password: params.password,
    ));
  }

  static Future<bool> createKeePassFileImpl(CreateParams params) async {
    try {
      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(params.password),
      );

      final kdbx = KdbxDatabase.create(
        name: params.name,
        credentials: credentials,
      );

      // 设置数据库信息
      kdbx.meta
        ..description = params.description
        ..defaultUser = ''
        ..maintenanceHistoryDays = 365
        ..recycleBinEnabled = true
        ..historyMaxItems = 10
        ..historyMaxSize = 6 * 1024 * 1024; // 6MB

      // 保存文件
      final bytes = await kdbx.save();
      final file = File(params.filePath);
      file.writeAsBytesSync(bytes);

      return true;
    } catch (e) {
      return false;
    }
  }

}
