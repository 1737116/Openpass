import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'local_storage_service.dart';
import 'biometric_service.dart';

class AppSettingsService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late LocalStorageService _localStorageService;

  // 本地变量
  String? _appIconPath;
  String _nickname = '';
  ThemeMode _savedThemeMode = ThemeMode.system;
  int _savedLayout = 0;
  bool _biometricEnabled = false;

  ThemeMode get savedThemeMode => _savedThemeMode;
  int get savedLayout => _savedLayout;

  void setLocalStorageService(LocalStorageService v) {
    _localStorageService = v;
  }

  Future<void> loadBasicSettings() async {
    try {
      String baseCfgFilename = await _localStorageService.userBaseCfgFilePath();
      final configFile = File(baseCfgFilename);
      if (await configFile.exists()) {
        final jsonString = await configFile.readAsString();
        final Map<String, dynamic> config = json.decode(jsonString);

        // 读取配置项到本地变量
        _appIconPath = _readStr(config, 'app_icon', '');
        _nickname = _readStr(config, 'nickname', '');
        _biometricEnabled = _readBool(config, 'biometricEnabled', false);
        _savedLayout = _readInt(config, 'layout_mode', 0);
        int themeMode = _readInt(config, 'theme_mode', 0);
        
        switch (themeMode) {
          case 1:
            _savedThemeMode = ThemeMode.light;
            break;
          case 2:
            _savedThemeMode = ThemeMode.dark;
            break;
          default:
            _savedThemeMode = ThemeMode.system;
            break;
        }
      }
      print('_appIconPath: $_appIconPath');
    } catch (e) {
      print("Error loading basic settings: $e");
    }
  }

  bool _readBool(Map<String, dynamic> config, String key, bool defaultValue) {
    var v = config[key];
    if (v!=null && (v is bool)){
      return v;
    }
    return defaultValue;
  }

  int _readInt(Map<String, dynamic> config, String key, int defaultValue) {
    var v = config[key];
    if (v!=null && (v is int)){
      return v;
    }
    return defaultValue;
  }

  String _readStr(Map<String, dynamic> config, String key, String defaultValue) {
    var v = config[key];
    if (v!=null && (v is String)){
      return v;
    }
    return defaultValue;
  }

  // 保存配置到文件
  Future<void> _saveConfigToFile() async {
    try {
      String baseCfgFilename = await _localStorageService.userBaseCfgFilePath();
      final configFile = File(baseCfgFilename);
      final Map<String, dynamic> config = {
        'app_icon': _appIconPath,
        'layout_mode': _savedLayout,
        'theme_mode': _savedThemeMode == ThemeMode.light ? 1 : _savedThemeMode == ThemeMode.dark ? 2 : 0,
        'nickname': _nickname,
        'biometricEnabled': _biometricEnabled,
      };
      
      await configFile.writeAsString(json.encode(config));
    } catch (e) {
      print("Error saving config to file: $e");
    }
  }

  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.clear();

      String baseCfgFilename = await _localStorageService.userBaseCfgFilePath();
      final configFile = File(baseCfgFilename);
      if (await configFile.exists()) {
        configFile.delete();
      }

      _secureStorage.delete(key: 'uuid');
      _secureStorage.delete(key: 'master_key');

      _nickname = '';
      _appIconPath = null;
      _savedThemeMode = ThemeMode.system;
      _savedLayout = 0;
    } catch (e) {
      print("Error delete config file: $e");
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _savedThemeMode = mode;
    _saveConfigToFile();
  }

  Future<void> setLayoutMode(int layoutMode) async {
    _savedLayout = layoutMode;
    _saveConfigToFile();
  }

  Future<bool> setBiometricEnabled(bool v) async {
    if (v) {
      // const iOSOptions = IOSOptions(
      //   accessibility: KeychainAccessibility.passcode, // 必须已启用设备密码
      //   accessibility: KeychainAccessibility.biometryAny,   // 需要生物识别验证
      // );
      String? bioPwd = await _localStorageService.getPwdForBio();
      if (bioPwd==null) return false;

      final biometricService = BiometricService();
      if (!await biometricService.checkBiometrics()) {
        return false;
      }
      if (!biometricService.isEnabled()) {
        return false;
      }
      if (!await biometricService.authenticate(reason: '请使用生物识别验证')) {
        return false;
      }

      // 验证成功
      //int typeCode = biometricService.getTypeCode();

      await _secureStorage.write(key:'master_pwd', value: bioPwd);
    }else{
      await _secureStorage.delete(key:'master_pwd');
    }
    _biometricEnabled = v;
    _saveConfigToFile();
    return true;
  }

  // 设置应用图标
  Future<void> setAppIcon(String iconPath) async {
    _appIconPath = iconPath;
    _saveConfigToFile();
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('app_icon', iconPath);
  }

  Future<void> setNickname(String nickname) async {
    _nickname = nickname;
    _saveConfigToFile();
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('nickname', nickname);
  }

  // 获取应用图标
  String? getAppIcon() {
    return _appIconPath;
  }
  
  String getNickname() {
    return _nickname;
  }

  // 安全地获取UUID
  Future<String> getUserUUID() async {
    // 从 SecureStorage 中读取
    return await _secureStorage.read(key: 'uuid')??'';
  }
  // 安全地存储主密钥
  Future<void> setUserUUID(String key) async {
    await _secureStorage.write(key: 'uuid', value: key);
  }
  // 安全地获取主密钥
  Future<String> getMasterKey() async {
    // 从 SecureStorage 中读取
    return await _secureStorage.read(key: 'master_key')??'';
  }
  // 安全地存储主密钥
  Future<void> setMasterKey(String key) async {
    await _secureStorage.write(key: 'master_key', value: key);
  }

  // 是否启用生物识别
  bool isUseBiometrics() {
    return _biometricEnabled;
  }

  // 安全地获取主密码
  Future<String> getMasterPwd() async {
    // 从 SecureStorage 中读取
    return await _secureStorage.read(key: 'master_pwd')??'';
  }
}
