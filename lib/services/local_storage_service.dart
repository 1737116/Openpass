import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:openpass_cloud/models/database_model.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../utils/local_data_encrypt.dart';
// import '../utils/keepass_utils.dart';
import '../utils/secret_utils.dart';
import '../models/database_info.dart';
import '../models/user_data.dart';
import '../models/setting_item.dart';
import 'layout_service.dart';
import 'theme_service.dart';
import 'app_settings_service.dart';

class LocalStorageService {
  static final _log = Logger('LocalStorage');
  static const int maxRecentFiles = 5;
  final _localDataEncrypt = LocalDataEncrypt();
  final ThemeService _themeService;
  final AppSettingsService _appSettingsService;
  final LayoutService _layoutService;
  
  String _uuidInStart = '';
  String? _encryptedData; // 密文，如果解密后这个值为null
  UserData _userData = UserData();
  bool _isUnlocked = false;
  bool _isChanged = false;
  bool _isFirstCreate = false;

  List<DatabaseInfo> get databaseItems => List.unmodifiable(_userData.files);
  List<FavoriteItem> get favoriteIds => List.unmodifiable(_userData.favorites);
  List<QuickAccessItem> get quickAccessItems => List.unmodifiable(_userData.quickAccess);
  List<RecentSearchItem> get recentSearches => List.unmodifiable(_userData.recentSearches);
  SettingManager get settings => _userData.settingManager;

  LocalStorageService(
    AppSettingsService appSettingsService,
    ThemeService themeService,
    LayoutService layoutService,
  )
    : _themeService = themeService
    , _appSettingsService = appSettingsService
    , _layoutService = layoutService;

  Future<void> onAppInit() async {
    _appSettingsService.setLocalStorageService(this);
    // 检查start文件，并读取到 uuid
    try {
      String startCfgFile = await _appStartFilePath();
      final startFile = File(startCfgFile);
      if (await startFile.exists()) {
        final jsonString = await startFile.readAsString();
        final Map<String, dynamic> config = json.decode(jsonString);
        var uuid = config['uuid'];
        if (uuid!=null && uuid is String){
          _uuidInStart = uuid;
          print('UUID: $uuid');
        }
      }
    } catch (e) {
      print("Error onAppInit: $e");
    }
  }

  String getUUID() {
    return _uuidInStart;
  }

  String getNickname() {
    return _userData.nickname;
  }

  String getAppIcon() {
    return _userData.appIcon;
  }

  Future<void> setNickname(String nickname) async {
    await _appSettingsService.setNickname(nickname);
    _userData.nickname = nickname;
    _isChanged = true;
    await autoSave();
  }

  Future<void> setAppIcon(String appIcon) async {
    await _appSettingsService.setAppIcon(appIcon);
    _userData.appIcon = appIcon;
    _isChanged = true;
    await autoSave();
  }

  Future<void> setDatabaseIcon(OPDatabase db, String icon) async {
    db.setDatabaseIcon(icon);
    _isChanged = true;
    await autoSave();
  }

  Future<void> setUuid(String uuid) async {
    if (uuid.isEmpty) return;
    if (_uuidInStart != uuid){
      _uuidInStart = uuid;
      // 写入start.cfg
      try {
        String startCfgFile = await _appStartFilePath();
        final startFile = File(startCfgFile);
        final Map<String, dynamic> config = {
          'uuid': uuid,
        };
        await startFile.writeAsString(json.encode(config));
      } catch (e) {
        print("Error saving start.cfg to file: $e");
      }
    }
  }

  // app根目录
  Future<Directory> _getAppDir() async {
    final rootDir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${rootDir.path}/openpass');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  // 当前保险库目录
  Future<Directory> getBaseDir() async {
    final appDir = await _getAppDir();
    final uuid = getUUID();
    final baseDir = Directory(path.join(appDir.path, uuid));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  // app启动文件，里面明文保存了uuid
  Future<String> _appStartFilePath() async {
    var ad = await _getAppDir();
    return '${ad.path}/start.cfg';
  }

  // 用户本地配置文件，里面明文保存了: 图标,昵称等本地明文可见信息
  Future<String> userBaseCfgFilePath() async {
    var bd = await getBaseDir();
    return '${bd.path}/base.cfg';
  }

  // 主加密文件
  Future<String> _userDataPath() async {
    var bd = await getBaseDir();
    return '${bd.path}/maindata';
  }

  // 数据库存放目录
  Future<Directory> getDatabaseRoot() async {
    final appDir = await _getAppDir();
    final uuid = getUUID();
    final databaseDir = Directory(path.join(appDir.path, uuid, 'db'));
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }
    return databaseDir;
  }

  Future<String> getDatabasePath(
      String virtualFilePath, bool createIfNotExists) async {
    // 把虚拟的文件路径转换成实际文件路径，主要是使用 '#' 代替应用路径
    if (virtualFilePath.isNotEmpty &&
        virtualFilePath.length > 1 &&
        virtualFilePath.substring(0, 1) == '#') {
      final opDir = await getDatabaseRoot();
      if (createIfNotExists) {
        if (!await opDir.exists()) {
          await opDir.create(recursive: true);
        }
      }
      return "${opDir.path}${virtualFilePath.substring(1)}";
    }
    return virtualFilePath;
  }

  // 从本地查找，从 000 开始查找，一直查找到 999，不存在的文件就返回作为文件名
  Future<String> getNewDatabaseFilename() async {
    final rootDir = await getDatabaseRoot();
    for (int i = 0; i < 1000; i++) {
      final fileName = '${i.toString().padLeft(3, '0')}.kdbx';
      File file = File('${rootDir.path}/$fileName');
      if (!await file.exists()) {
        return fileName;
      }
    }
    return const Uuid().v4();
  }

  // 图标缓存目录
  Future<Directory> getIconCacheDir() async {
    final appDir = await _getAppDir();
    final uuid = getUUID();
    final iconCacheDir = Directory(path.join(appDir.path, uuid, 'icon_caches'));
    if (!await iconCacheDir.exists()) {
      await iconCacheDir.create(recursive: true);
    }
    return iconCacheDir;
  }

  Future<void> setUserData(String uuid, String nickname, String appIcon, String publicKey, String privateKey, String masterKey) async {
    print('UUID: $uuid');
    await setUuid(uuid);
    _userData.userID = uuid;
    _userData.nickname = nickname;
    _userData.appIcon = appIcon;
    _userData.rsaPublicKey = publicKey;
    _userData.rsaPrivateKey = privateKey;
    _userData.masterKey = masterKey;
    _isFirstCreate = true;
    // print('uuid: $uuid');
    // print('nickname: $nickname');

    try {
      String startCfgFile = await _appStartFilePath();
      final startFile = File(startCfgFile);
      final Map<String, dynamic> config = {
        'uuid': uuid,
      };
      await startFile.writeAsString(json.encode(config));
    } catch (e) {
      print("Error saving start.cfg to file: $e");
    }
  }

  Future<void> setupPassword(String password) async {
    _localDataEncrypt.setMasterPassword(password);
  }

  // 获取用于生物识别的密码
  Future<String?> getPwdForBio() async {
    return _localDataEncrypt.getPwdForBio();
  }

  Future<void> setPwdByBio(String pwd) async {
    _localDataEncrypt.setPwdByBio(pwd);
  }

  Future<void> setupKeyAndSalt(String masterKey, String uuid) async {
    _localDataEncrypt.setMasterKey(masterKey);
    _localDataEncrypt.setSalt(uuid);
  }

  bool isPasswordVaild() {
    return _localDataEncrypt.isPasswordVaild();
  }

  bool validateCurrentPassword(String currentPassword) {
    return _localDataEncrypt.validateCurrentPassword(currentPassword);
  }

  Future<bool> changeMasterPassword(String newMasterPassword) async {
    if (_isUnlocked==false) {
      return false; // 尚未解锁
    }
    if (!await _localDataEncrypt.changeMasterPassword(newMasterPassword)) {
      return false;
    }
    await saveUserData();
    return true;
  }

  // 使用密码解锁
  Future<bool> unlockByPassword() async {
    if (_isUnlocked) {
      return true;
    }

    if (_localDataEncrypt.isMasterKeyNull()){
      var mk = await _appSettingsService.getMasterKey();
      _localDataEncrypt.setMasterKey(mk);
    }

    if (_localDataEncrypt.isSaltNull()){
      var uuid = await _appSettingsService.getUserUUID();
      _localDataEncrypt.setSalt(uuid);
    }

    return await _decryptUserData();
  }

  // 添加最近文件
  Future<DatabaseInfo> updateDatabaseList(String filePath, String? password, String? keyData, bool saveDatabasePassword, String dbName) async {
    // 查找现有文件
    DatabaseInfo existingFile = _userData.files.firstWhere(
      (f) => f.filePath == filePath,
      orElse: () => DatabaseInfo(filePath: filePath),
    );

    // 更新或创建文件记录
    var np = saveDatabasePassword ? password : null;
    if (existingFile.password != np) {
      existingFile.password = np;
      _isChanged = true;
    }
    if (existingFile.keyData != keyData) {
      existingFile.keyData = keyData;
      _isChanged = true;
    }
    if (existingFile.name != dbName) {
      existingFile.name = dbName;
      _isChanged = true;
    }

    // 如果是新文件，添加到列表
    if (!_userData.files.contains(existingFile)) {
      _userData.files.insert(0, existingFile);
      if (_userData.files.length > maxRecentFiles) {
        _userData.files.removeLast();
      }
      _isChanged = true;
    }

    await autoSave();
    return existingFile;
  }

  Future<void> deleteDatabaseList(DatabaseInfo dbInfo) async {
    _userData.files.remove(dbInfo);
  }

  // 更新密钥数据
  Future<void> updateDatabaseKeyData(String fileId, String? keyData) async {
    for (final file in _userData.files) {
      if (file.id == fileId) {
        if (file.keyData!=keyData) {
          file.keyData = keyData;
          _isChanged = true;
          await autoSave();
          return;
        }
      }
    }
  }

  // 收藏夹相关方法
  Future<void> addFavorite(String dbId, String itemId) async {
    if (!_userData.favorites.any((f) => f.dbId==dbId && f.itemId == itemId)) {
      _userData.favorites.add(FavoriteItem(dbId: dbId, itemId: itemId));
      _isChanged = true;
      await autoSave();
    }
  }

  Future<void> removeFavorite(String dbId, String itemId) async {
    _userData.favorites.removeWhere((f) => f.dbId==dbId && f.itemId == itemId);
    _isChanged = true;
    await autoSave();
  }

  bool isFavorite(String dbId, String itemId) {
    return _userData.favorites.any((f) => f.dbId==dbId && f.itemId == itemId);
  }

  // 快速访问相关方法
  Future<void> addQuickAccess(String dbId, String itemId, String name) async {
    if (!_userData.quickAccess.any((f) => f.dbId==dbId && f.itemId == itemId && f.fieldName == name)) {
      _userData.quickAccess.add(QuickAccessItem(dbId: dbId, itemId: itemId, fieldName: name));
      _isChanged = true;
      await autoSave();
    }
  }

  Future<void> removeQuickAccess(String dbId, String itemId, String name) async {
    _userData.quickAccess.removeWhere((f) => f.dbId==dbId && f.itemId == itemId && f.fieldName == name);
    _isChanged = true;
    await autoSave();
  }

  bool isQuickAccess(String dbId, String itemId, String name) {
    return _userData.quickAccess.any((f) => f.dbId==dbId && f.itemId == itemId && f.fieldName == name);
  }

  // 注意：这里不直接存盘，避免卡UI
  void addRecentSearch(String dbId, String itemId) {
    var item = RecentSearchItem(dbId: dbId, itemId: itemId);
    _userData.recentSearches.removeWhere((element) => 
      element.dbId == dbId && element.itemId == itemId);
    _userData.recentSearches.insert(0, item);
    
    // 限制最多保存30条记录
    if (_userData.recentSearches.length > 30) {
      _userData.recentSearches = _userData.recentSearches.sublist(0, 30);
    }
    _isChanged = true;
  }

  // 注意：这里不直接存盘，避免卡UI
  void clearRecentSearches() {
    _userData.recentSearches.clear();
    _isChanged = true;
  }

  SettingItem? getSettingByKey(String key) {
    return settings.get(key);
  }

  bool getSettingBool(String key) {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingValueType.bool) {
      return s.value??s.defaultValue;
    }
    return false;
  }

  int getSettingInt(String key) {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingValueType.int) {
      return s.value??s.defaultValue;
    }
    return 0;
  }
  
  String getSettingStr(String key) {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingValueType.string) {
      return s.value??s.defaultValue;
    }
    return "";
  }
  
  Future<void> setSettingBool(String key, bool v) async {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingItem.getValueType(v)) {
      var old = s.value;
      s.value = v;
      if (!await onSettingItemChanged(s)){
        s.value = old;
      }
    }
  }

  Future<void> setSettingInt(String key, int v) async {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingItem.getValueType(v)) {
      var old = s.value;
      s.value = v;
      if (!await onSettingItemChanged(s)){
        s.value = old;
      }
    }
  }

  Future<void> setSettingStr(String key, String v) async {
    SettingItem? s = getSettingByKey(key);
    if (s!=null && s.type==SettingItem.getValueType(v)) {
      var old = s.value;
      s.value = v;
      if (!await onSettingItemChanged(s)){
        s.value = old;
      }
    }
  }

  // 更新项目名称
  Future<void> updateEntryFieldName(String dbId, String itemId, String fieldName, String newName) async {
    for (var item in _userData.quickAccess) {
      if (item.dbId == dbId && item.itemId == itemId && item.fieldName == fieldName) {
        item.fieldName = newName;
        _isChanged = true;
      }
    }
    await autoSave();
  }

  Future<bool> _decryptUserData() async {
    if (_isUnlocked) {
      return true;
    }
    try {
      if (_encryptedData == null || _encryptedData!.isEmpty || _encryptedData!.length < 2) {
        return false;
      }

      // 返回明文
      String? plainData = await _localDataEncrypt.decryptMainDataWarp(_encryptedData!);
      if (plainData == null) {
        return false;
      }

      _encryptedData = null;
      final jsonData = jsonDecode(plainData);
      _userData = UserData.fromJson(jsonData);

      await setUuid(_userData.userID);
      final iconPath1 = getAppIcon();
      final nickname1 = getNickname();
      final iconPath2 = _appSettingsService.getAppIcon();
      final nickname2 = _appSettingsService.getNickname();
      if (nickname1!=nickname2){
        _appSettingsService.setNickname(nickname1);
      }
      if (iconPath1!=iconPath2){
        _appSettingsService.setAppIcon(iconPath1);
      }

      _isUnlocked = true;
      return true;
    } catch (e) {
      _log.warning('加载数据失败', e);
      _userData = UserData();
      return false;
    }
  }

  // 读取保存的数据
  Future<bool> loadUserData({bool clearBefore=false}) async {
    if (clearBefore){
      _encryptedData = null;
    }

    if (_encryptedData==null) {
      final file = File(await _userDataPath());
      if (await file.exists()) {
        _encryptedData = await file.readAsString();
      } else {
        _encryptedData = '{}';
      }
    }
    _themeService.onAfterLocalStorageInit(this);
    _layoutService.onAfterLocalStorageInit(this);
    _isFirstCreate = false;
    return _encryptedData!=null && _encryptedData!.isNotEmpty && _encryptedData!.length>2;
  }

  Future<void> autoSave() async {
    // 如果未修改，不保存
    if (_isChanged==false) {
      return;
    }
    // 如果是首次创建，不保存。因为首次创建会在最后强制保存
    if (_isFirstCreate==true) {
      return;
    }
    await saveUserData();
  }

  Future<void> saveUserData() async {
    try {
      final jsonStr = jsonEncode(_userData.toJson());
      if (jsonStr.isNotEmpty && jsonStr.length>2) {
        var encryptedData = await _localDataEncrypt.encryptMainDataWarp(jsonStr);
        if (encryptedData!=null){
          final file = File(await _userDataPath());
          await file.writeAsString(encryptedData);
        }
      }
      _isChanged = false;
    } catch (e) {
      _log.warning('保存数据失败', e);
      rethrow;
    }
  }

  


  // 清除内存数据
  Future<void> clearMemoryData() async {
    _userData = UserData();
    await _localDataEncrypt.clearData();
    _isFirstCreate = false;
    _isUnlocked = false;
    _isChanged = false;
  }

  Future<void> lock() async {
    await clearMemoryData();
    await loadUserData();
  }

  // 清除所有数据（不可恢复）
  Future<void> clearLocalData() async {
    await clearMemoryData();
    final appDir = await _getAppDir();
    // 删除 baseDir 目录和下面的所有文件
    if (await appDir.exists()) {
      await appDir.delete(recursive: true);
    }
    await onAppInit(); // 重新创建根目录
  }
  
  // 自动锁定时间相关方法
  int getAutoLockTime() {
    return getSettingInt('auto_lock_time');
  }
  
  void setAutoLockTime(int minutes) {
    setSettingInt('auto_lock_time', minutes);
  }
  
  // 网站图标显示相关方法
  bool getShowWebsiteIcons() {
    return getSettingBool('show_website_icons');
  }
  
  void setShowWebsiteIcons(bool value) {
    setSettingBool('show_website_icons', value);
  }

  Future<bool> onSettingItemChanged(SettingItem item) async {
    bool ret = true;
    switch (item.key)
    {
      case 'theme_mode': await _onThemeModeChanged(item); break;
      case 'layout_mode': await _onLayoutModeChanged(item); break;
      case 'biometric_enabled': ret = await _onBiometricEnableChanged(item); break;
    }
    _isChanged = true;
    autoSave();
    return ret;
  }

  Future<void> _onThemeModeChanged(SettingItem item) async {
    int modeVal = (item.value is int) ? item.value : 0;
    ThemeMode mode = ThemeMode.values[modeVal];
    await _appSettingsService.setThemeMode(mode);
    _themeService.onThemeChanged();
  }

  Future<void> _onLayoutModeChanged(SettingItem item) async {
    int mode = (item.value is int) ? item.value : 0;
    await _appSettingsService.setLayoutMode(mode);
    _layoutService.onLayoutChanged();
  }

  Future<bool> _onBiometricEnableChanged(SettingItem item) async {
    bool mode = (item.value is bool) ? item.value : false;
    return await _appSettingsService.setBiometricEnabled(mode);
  }

  // 存储Favicon加密密钥
  Future<void> storeEncryptionKey(String keyName, String keyData) async {
    try {
      // 使用RSA公钥加密密钥数据
      final encryptedData = SecretUtils.encryptWithRSA(_userData.rsaPublicKey, keyData);
      
      // 将加密后的数据存储在用户数据中
      _userData.encryptionKeys[keyName] = encryptedData;
      _isChanged = true;
      await autoSave();
    } catch (e) {
      _log.warning('保存加密密钥 $keyName 失败', e);
    }
  }

  // 获取Favicon加密密钥
  Future<AesKeyIv?> getEncryptionKey(String keyName, bool genIfInexists) async {
    try {
      // 检查是否有存储的加密密钥
      final encryptedKeys = _userData.encryptionKeys;
      var encryptedKey = encryptedKeys[keyName];
      if (encryptedKey==null || encryptedKey.isEmpty) {
        if (genIfInexists) {
          return await _generateAndStoreKeys(keyName);
        } else {
          return null;
        }
      }
      
      // 使用RSA私钥解密数据
      final keyJson = SecretUtils.decryptWithRSA(_userData.rsaPrivateKey, encryptedKey);
      if (keyJson == null) {
        return null;
      }

      final keysMap = jsonDecode(keyJson);
      var key = encrypt.Key(base64Decode(keysMap['key'] as String));
      var iv = encrypt.IV(base64Decode(keysMap['iv'] as String));
      return AesKeyIv(key,iv);
    } catch (e) {
      _log.warning('获取密钥 $keyName 失败', e);
      return null;
    }
  }
  
  // 生成并存储新的加密密钥
  Future<AesKeyIv?> _generateAndStoreKeys(String keyName) async {
    // 生成随机密钥
    final keyBytes = SecretUtils.generateRandomBytes(32);
    final ivBytes = SecretUtils.generateRandomBytes(16);

    final keysMap = {
      'key': base64Encode(keyBytes),
      'iv': base64Encode(ivBytes),
    };
    await storeEncryptionKey(keyName, jsonEncode(keysMap));

    var key = encrypt.Key(keyBytes);
    var iv = encrypt.IV(ivBytes);
    return AesKeyIv(key,iv);
  }
  
}
