import 'package:flutter/material.dart';
import '../i18n/translations.dart';

enum SettingValueType {
  bool,
  int,
  string,
  func,
}

class SettingItemSelectItem {
  String name;
  String value;
  SettingItemSelectItem({
    required this.name,
    required this.value,
  });
}

class SettingItem {
  final String key;
  SettingValueType type = SettingValueType.bool;
  dynamic value;
  dynamic defaultValue = false;
  List<SettingItemSelectItem>? selectItems;

  SettingItem(
    String k,
    dynamic v,
    {
      this.selectItems
    }) : key=k,value=v {
    if (value != null) {
      type = getValueType(value);
    }else {
      type = SettingValueType.bool;
      value = false;
    }
    defaultValue = value;
  }

  static SettingValueType getValueType(dynamic v){
    switch(v.runtimeType) {
      case bool:
        return SettingValueType.bool;
      case int:
        return SettingValueType.int;
      case String:
        return SettingValueType.string;
      default:
        return SettingValueType.func;
      }
  }

}

//////////////////////////////////////////


// 一个设置树节点
class SettingTreeItem {
  final String key;
  final IconData? icon;
  final Color? color;
  final List<SettingTreeItem>? children;
  SettingTreeItem? parent;

  int get childNum => children==null?0:children!.length;

  SettingTreeItem(String k, {
    this.icon,
    this.color,
    this.children,
  }):key=k;
  
  // 获取设置项的显示名称
  String name(AppLocalizations translations) {
    var key = this.key;
    if (key.startsWith('#')) {
      // 分组标题，去掉前缀 '#'
      key = key.substring(1);
    } else if (key.startsWith(':')) {
      // 特殊处理项，去掉前缀 ':'
      key = key.substring(1);
    } else {
    }
    return translations.get(key);
  }
  
  // 获取设置项的描述
  String desc(AppLocalizations translations) {
    var key = this.key;
    if (key.startsWith('#')) {
      // 分组标题，去掉前缀 '#'
      key = key.substring(1);
    } else if (key.startsWith(':')) {
      // 特殊处理项，去掉前缀 ':'
      key = key.substring(1);
    } else {
    }
    return translations.getOrNull('${key}_desc')??'';
  }
}

// 设置管理
class SettingManager {
  final Map<String, SettingItem> _settings = {};
  late SettingTreeItem root;
  late SettingTreeItem dbRoot;

  SettingManager() {
    List<SettingItemSelectItem> autoLockTimeOptions = [
      SettingItemSelectItem(name:"1 分钟", value: "60"),
      SettingItemSelectItem(name:"5 分钟", value: "300"),
      SettingItemSelectItem(name:"10 分钟", value: "600"),
      SettingItemSelectItem(name:"15 分钟", value: "900"),
      SettingItemSelectItem(name:"30 分钟", value: "1800"),
      SettingItemSelectItem(name:"1 小时", value: "3600"),
      SettingItemSelectItem(name:"2 小时", value: "7200"),
    ];
    List<SettingItemSelectItem> darkModeOptions = [
      SettingItemSelectItem(name:"跟随系统", value: "0"),
      SettingItemSelectItem(name:"浅色系统", value: "1"),
      SettingItemSelectItem(name:"深色系统", value: "2"),
    ];
    List<SettingItemSelectItem> layoutModeOptions = [
      SettingItemSelectItem(name:"系统自动", value: "0"),
      SettingItemSelectItem(name:"手机布局", value: "1"),
      SettingItemSelectItem(name:"电脑布局", value: "2"),
    ];
    List<SettingItemSelectItem> languageOptions = [
      SettingItemSelectItem(name:"中文", value: "zh"),
      SettingItemSelectItem(name:"英文", value: "en"),
    ];

    List<SettingItem> all = [
      SettingItem("biometric_enabled", false),
      SettingItem("auto_lock_time", 60, selectItems: autoLockTimeOptions),
      SettingItem("show_website_icons", true),
      SettingItem("theme_mode", 0, selectItems: darkModeOptions),
      SettingItem("layout_mode", 0, selectItems: layoutModeOptions),
      SettingItem("language", "zh", selectItems: languageOptions),
      SettingItem("gen_password", "{}"), // 密码生成配置，用于密码生成对话框
    ];

    

    for (var e in all) {
      _settings[e.key] = e;
    }
    _makeAppSetting();
    _makeDbSetting();
  }

  SettingItem? get(String key){
    return _settings[key];
  }

  // 返回 setting中值和默认值不同的
  Map<String,dynamic> get modifiedSettings {
    Map<String,dynamic> res = {};
    for (var e in _settings.values) {
      if (e.value != e.defaultValue) {
        res[e.key] = e.value;
      }
    }
    return res;
  }

  void _makeAppSetting(){
    root = SettingTreeItem("",
      children: [
        // SettingTreeItem(":profile"),

        SettingTreeItem("#security_setting"),
        SettingTreeItem("nickname", icon: Icons.person),
        SettingTreeItem("app_icon", icon: Icons.image),
        SettingTreeItem("master_password", icon: Icons.lock),
        SettingTreeItem("master_key", icon: Icons.key),
        SettingTreeItem("biometric_enabled", icon: Icons.fingerprint),
        SettingTreeItem("auto_lock_time", icon: Icons.timer),

        SettingTreeItem("#databases"),
        SettingTreeItem(":allDatabase"),

        SettingTreeItem("#privacy_settings"),
        SettingTreeItem("show_website_icons", icon: Icons.image),

        SettingTreeItem("#data_management"),
        // SettingTreeItem("backup", icon: Icons.backup),
        // SettingTreeItem("recover", icon: Icons.restore),
        // SettingTreeItem("sync", icon: Icons.sync,
        //   children: [
        //     SettingTreeItem("sync_icloud", icon: Icons.sync),
        //     SettingTreeItem("sync_baidu", icon: Icons.sync),
        //     SettingTreeItem("sync_weiyun", icon: Icons.sync),
        //   ],
        // ),
        SettingTreeItem("erase_data", icon: Icons.delete,
          children: [
            SettingTreeItem("erase_local_data", icon: Icons.delete),
          ],
        ),

        SettingTreeItem("#appearance"),
        SettingTreeItem("theme_mode", icon: Icons.dark_mode),
        SettingTreeItem("language", icon: Icons.language),
        SettingTreeItem("layout_mode", icon: Icons.phone),

        SettingTreeItem("#about"),
        SettingTreeItem("about_app", icon: Icons.info),
        SettingTreeItem("help", icon: Icons.help),

      ],
    );
    _updateParent(root);
  }

  void _makeDbSetting(){
    dbRoot = SettingTreeItem("",
      children: [
        SettingTreeItem("#base"),
        SettingTreeItem(":database_icon", icon: Icons.lock),
        SettingTreeItem("name", icon: Icons.key),
        SettingTreeItem("desc", icon: Icons.fingerprint),
        SettingTreeItem("UUID", icon: Icons.timer),
        SettingTreeItem("file", icon: Icons.timer),

        SettingTreeItem("#history"),
        SettingTreeItem("historyMaxItems"),
        SettingTreeItem("historyMaxSize"),
        SettingTreeItem("recycleBinEnabled"),

        SettingTreeItem("#operate"),
        SettingTreeItem("op_import_kdbx", icon: Icons.import_contacts, color: Colors.green),
        SettingTreeItem("op_lock_database", icon: Icons.lock, color: Colors.blue),
        SettingTreeItem("op_delete_database", icon: Icons.delete_forever, color: Colors.red),
      ],
    );
    _updateParent(dbRoot);
  }

  void _updateParent(SettingTreeItem parent){
    // 更新树节点的 parent
    if (parent.children!=null) {
      for(var i in parent.children!){
        i.parent = parent;
        _updateParent(i);
      }
    }
  }

  void fromJson(dynamic json) {
    if (json is Map){
      for (var e in json.entries) {
        var item = _settings[e.key];
        if (item!=null){
          if (e.value.runtimeType==item.defaultValue.runtimeType){
            item.value = e.value;
          }
        }
      }
    }
    
  }

}
