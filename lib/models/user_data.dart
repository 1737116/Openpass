import 'database_info.dart';
import 'setting_item.dart';

class FavoriteItem {
  final String dbId;
  final String itemId;

  FavoriteItem({
    required this.dbId,
    required this.itemId,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      dbId: json['dbId'] as String,
      itemId: json['itemId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dbId': dbId,
      'itemId': itemId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItem &&
          runtimeType == other.runtimeType &&
          dbId == other.dbId &&
          itemId == other.itemId;

  @override
  int get hashCode => dbId.hashCode ^ itemId.hashCode;
}

class QuickAccessItem {
  final String dbId;
  final String itemId;
  String fieldName;

  QuickAccessItem({
    required this.dbId,
    required this.itemId,
    required this.fieldName,
  });

  factory QuickAccessItem.fromJson(Map<String, dynamic> json) {
    return QuickAccessItem(
      dbId: json['dbId'] as String,
      itemId: json['itemId'] as String,
      fieldName: json['fieldId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dbId': dbId,
      'itemId': itemId,
      'fieldId': fieldName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickAccessItem &&
          runtimeType == other.runtimeType &&
          dbId == other.dbId &&
          itemId == other.itemId &&
          fieldName == other.fieldName;

  @override
  int get hashCode => dbId.hashCode ^ itemId.hashCode ^ fieldName.hashCode;
}

class RecentSearchItem {
  final String dbId;
  final String itemId;
  final DateTime accessTime;

  RecentSearchItem({
    required this.dbId,
    required this.itemId,
    DateTime? accessTime,
  }) : accessTime = accessTime ?? DateTime.now();

  factory RecentSearchItem.fromJson(Map<String, dynamic> json) {
    return RecentSearchItem(
      dbId: json['dbId'] as String,
      itemId: json['itemId'] as String,
      accessTime: DateTime.parse(json['accessTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dbId': dbId,
      'itemId': itemId,
      'accessTime': accessTime.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSearchItem &&
          runtimeType == other.runtimeType &&
          dbId == other.dbId &&
          itemId == other.itemId;

  @override
  int get hashCode => dbId.hashCode ^ itemId.hashCode;
}

class UserData {
  String userID = '';
  String nickname = '';
  String appIcon = '';
  String rsaPublicKey = '';
  String rsaPrivateKey = '';
  String masterKey = '';
  Map<String,String> encryptionKeys = {}; // 其他各种加密密钥
  List<DatabaseInfo> files = [];
  List<FavoriteItem> favorites = [];
  List<QuickAccessItem> quickAccess = [];
  List<RecentSearchItem> recentSearches = [];
  SettingManager settingManager = SettingManager();

  UserData();

  factory UserData.fromJson(Map<String, dynamic> json) {
    var ud = UserData();

    ud.files = (json['files'] as List?)
      ?.map((item) => DatabaseInfo.fromJson(item))
      .toList() ?? [];

    ud.favorites = (json['favorites'] as List?)
        ?.map((item) => FavoriteItem.fromJson(item))
        .toList() ?? [];
    ud.quickAccess = (json['quickAccess'] as List?)
        ?.map((item) => QuickAccessItem.fromJson(item))
        .toList() ?? [];
    ud.recentSearches = (json['recentSearches'] as List?)
        ?.map((item) => RecentSearchItem.fromJson(item))
        .toList() ?? [];

    ud.settingManager.fromJson(json['settings']);
    ud.userID = _readString(json, 'userID');
    ud.nickname = _readString(json, 'nickname');
    ud.appIcon = _readString(json, 'appIcon');
    ud.rsaPublicKey = _readString(json, 'rsaPublicKey');
    ud.rsaPrivateKey = _readString(json, 'rsaPrivateKey');
    ud.masterKey = _readString(json, 'masterKey');
    
    // 解析加密密钥
    if (json['encryptionKeys'] != null) {
      final encryptionKeysJson = json['encryptionKeys'] as Map<String, dynamic>;
      ud.encryptionKeys = encryptionKeysJson.map((key, value) => 
          MapEntry(key, value.toString()));
    }

    return ud;
  }
  static String _readString(Map<String, dynamic> json, String key) {
    return json[key] as String? ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'nickname': nickname,
      'appIcon': appIcon,
      'rsaPublicKey': rsaPublicKey,
      'rsaPrivateKey': rsaPrivateKey,
      'masterKey': masterKey,
      'encryptionKeys': encryptionKeys,
      'files': files.map((file) => file.toJson()).toList(),
      'favorites': favorites.map((item) => item.toJson()).toList(),
      'quickAccess': quickAccess.map((item) => item.toJson()).toList(),
      'recentSearches': recentSearches.map((item) => item.toJson()).toList(),
      'settings': settingManager.modifiedSettings,
    };
  }
}