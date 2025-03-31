// import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
// import 'package:crypto/crypto.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:openpass_cloud/utils/secret_utils.dart';
// import 'package:pointycastle/api.dart';
// import 'package:pointycastle/key_derivators/api.dart';
// import 'package:pointycastle/key_derivators/pbkdf2.dart';
// import 'package:pointycastle/digests/sha256.dart';
// import 'package:pointycastle/macs/hmac.dart';

class SecureMainDataParams {
  final String data;
  final String pwd;
  final String key;
  final Uint8List salt;

  SecureMainDataParams({
    required this.data,
    required this.pwd,
    required this.key,
    required this.salt,
  });
}

class LocalDataEncrypt {
  static final _log = Logger('LocalDataEncrypt');
  late final Uint8List _memoryEncryptionKey;
  late final Uint8List _memoryEncryptionIv;
  Uint8List? _encryptedPassword; // 内存中的密码（加密后）
  Uint8List? _encryptedMasterKey; // 哈希后的key
  Uint8List? _salt;

  // 构造函数，初始化时生成随机内存加密密钥
  LocalDataEncrypt() {
    // 生成随机的内存加密密钥和IV
    _memoryEncryptionKey = SecretUtils.generateRandomBytes(32); // AES-256 需要32字节密钥
    _memoryEncryptionIv = SecretUtils.generateRandomBytes(16);  // AES 需要16字节IV
  }

  // 设置密码
  void setMasterPassword(String password) {
    _encryptedPassword = null;
    if (password.isNotEmpty) {
      // 使用AES加密密码后存储在内存中
      final passwordBytes = utf8.encode(password);
      final encryptedPassword = SecretUtils.encryptWithKey(
        passwordBytes, _memoryEncryptionKey, _memoryEncryptionIv
      );

      if (encryptedPassword != null) {
        _encryptedPassword = encryptedPassword;
      } else {
        _log.warning('密码内存加密失败');
      }
    }
  }

  // 获取原始密码（解密内存中的密码）
  String? _getOriginalPassword() {
    if (_encryptedPassword == null) return null;
    
    try {
      final decryptedBytes = SecretUtils.decryptWithKey(
        _encryptedPassword!, _memoryEncryptionKey, _memoryEncryptionIv
      );

      if (decryptedBytes != null) {
        return utf8.decode(decryptedBytes);
      }
    } catch (e) {
      // 解密失败
    }
    return null;
  }
  
  bool isPasswordVaild() {
    return _encryptedPassword!=null;
  }

  bool validateCurrentPassword(String currentPassword) {
    return _getOriginalPassword() == currentPassword;
  }

  String? getPwdForBio() {
    return _getOriginalPassword();
  }

  void setPwdByBio(String pwd) {
    setMasterPassword(pwd);
  }

  // 更改主密码
  Future<bool> changeMasterPassword(String newMasterPassword) async {
    try {
      // 检查当前密码是否有效
      if (!isPasswordVaild()) {
        _log.warning('当前密码无效，无法更改');
        return false;
      }
      
      // 检查主密钥是否存在
      String? currentMasterKey = _getOriginalMasterKey();
      if (currentMasterKey == null || currentMasterKey.isEmpty) {
        _log.warning('主密钥不存在，无法更改密码');
        return false;
      }
      
      // 检查盐值是否存在
      if (isSaltNull()) {
        _log.warning('盐值不存在，无法更改密码');
        return false;
      }
      
      // 更新内存中的密码
      setMasterPassword(newMasterPassword);
      
      _log.info('主密码更改成功');
      return true;
    } catch (e) {
      _log.severe('更改主密码时发生错误', e);
      return false;
    }
  }

  // 设置主密钥
  void setMasterKey(String masterKey) {
      _encryptedMasterKey = null;
    if (masterKey.isNotEmpty) {
      // 使用AES加密密码后存储在内存中
      final plainBytes = utf8.encode(masterKey);
      final encryptedBytes = SecretUtils.encryptWithKey(
        plainBytes, _memoryEncryptionKey, _memoryEncryptionIv
      );

      if (encryptedBytes != null) {
        _encryptedMasterKey = encryptedBytes;
      } else {
        _log.warning('密码内存加密失败');
      }
    }
  }
  String? _getOriginalMasterKey() {
    if (_encryptedMasterKey == null) return null;
    
    try {
      final decryptedBytes = SecretUtils.decryptWithKey(
        _encryptedMasterKey!, _memoryEncryptionKey, _memoryEncryptionIv
      );

      if (decryptedBytes != null) {
        return utf8.decode(decryptedBytes);
      }
    } catch (e) {
      // 解密失败
    }
    return null;
  }

  bool isMasterKeyNull(){
    return _encryptedMasterKey==null || _encryptedMasterKey!.length<10;
  }

  // 根据账号信息获取盐值，账号信息为账号的唯一id
  void setSalt(String accountDesc) {
    _salt = null;
    // print('setSalt: $accountDesc');
    if (accountDesc.isNotEmpty) {
      _salt = SecretUtils.generateAccountSalt(accountDesc);
      // print('   : ${base64.encode(_salt!)}');
    }
  }

  bool isSaltNull(){
    return _salt==null || _salt!.length<10;
  }

  // 从 SharedPreferences 加载数据
  Future<String?> decryptMainDataWarp(String encryptedData) async {
    try {
      // 解密
      var pwd = _getOriginalPassword();
      var key = _getOriginalMasterKey();
      if (pwd==null || _encryptedMasterKey==null || _salt==null) {
        throw Exception('Decrypt params err');
      }
      final plainData = await compute<SecureMainDataParams, String?>(
        LocalDataEncrypt._decryptMainDataImpl,
        SecureMainDataParams(
          data: encryptedData,
          pwd: pwd,
          key: key!,
          salt: _salt!,
        ),
      );
      // 解密成功
      return plainData;
    } catch (e) {
      _log.warning('加载数据失败', e);
      rethrow;
    }
  }

  // 保存数据到 SharedPreferences
  Future<String?> encryptMainDataWarp(String plainData) async {
    try {
      String? encryptedData;
      // 如果有密码，使用密码加密
      var pwd = _getOriginalPassword();
      var key = _getOriginalMasterKey();

      if (pwd == null && key==null && _salt==null) {
        throw Exception('Encrypt params err');
      }

      encryptedData = await compute<SecureMainDataParams, String?>(
        LocalDataEncrypt._encryptMainDataImpl,
        SecureMainDataParams(
          data: plainData,
          pwd: pwd!,
          key: key!,
          salt: _salt!,
        ),
      );
      if (encryptedData == null) {
        return null;
      }
      
      return encryptedData;
    } catch (e) {
      _log.warning('保存数据失败', e);
      rethrow;
    }
  }

  Future<void> clearData() async {
    _encryptedPassword = null;
    _encryptedMasterKey = null;
    _salt = null;
  }

  // 加密数据
  static String? _encryptMainDataImpl(SecureMainDataParams params) {
    try {
      final plainBytes = utf8.encode(params.data);
      final encrypted = SecretUtils.encryptDataByPwdAndKey(plainBytes, params.pwd, params.key, params.salt);
      if (encrypted==null){
        return null;
      }
      return base64.encode(encrypted);
    } catch (e) {
      _log.warning('加密数据失败', e);
      return null;
    }
  }

  // 解密数据
  static String? _decryptMainDataImpl(SecureMainDataParams params) {
    try {
      final encryptedData = base64.decode(params.data);
      final plainBytes = SecretUtils.decryptDataByPwdAndKey(encryptedData, params.pwd, params.key, params.salt);
      if (plainBytes==null){
        return null;
      }
      return utf8.decode(plainBytes);
    } catch (e) {
      _log.warning('解密数据失败', e);
      return null;
    }
  }
}