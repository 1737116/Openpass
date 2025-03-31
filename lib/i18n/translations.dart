import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ?? 
        AppLocalizations(const Locale('zh', 'CN'));
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'username': 'Username',
      'password': 'Password',
      'url': 'URL',
      'email': 'Email',
      'phone': 'Phone',
      'note': 'Note',
      'otp': 'One-Time Password',
      'attachment': 'Attachment',
      'link': 'Link',
      'group': 'Group',
      'basic_info': 'Basic Information',
      'new_item': 'New Item',
      'default': 'Default',
      'security_question': 'Security Question',
      'text': 'Text',
      'address': 'Address',
      'date': 'Date',
      'loginModule': 'Login Module',
      'add_field': 'Add Field'
    },
    'zh': {
      'username': '用户名',
      'password': '密码',
      'url': '网址',
      'email': '邮箱',
      'phone': '电话',
      'note': '备注',
      'otp': '一次性密码',
      'attachment': '附件',
      'link': '链接',
      'group': '分组',
      'basic_info': '基本信息',
      'new_item': '新项目',
      'default': '默认',
      'security_question': '安全问题',
      'text': '文本',
      'address': '地址',
      'date': '日期',
      'loginModule': '登录方式',
      'add_field': '添加字段',

      'security_setting': '安全设置',
      'nickname': '昵称',
      'nickname_desc': '会显示在登录界面，便于识别是否是您的数据',
      'app_icon': '图标',
      'app_icon_desc': '定义您的个性图标，会显示在登录界面，便于识别是否是您的数据',
      'master_password': '主密码',
      'master_password_desc': '保护所有数据的密码，不存储在设备，忘记将无法恢复数据',
      'master_key': '主密钥',
      'master_key_desc': '仅保存在您允许的设备上，和密码结合保护数据，一旦丢失将无法恢复数据',
      'biometric_enabled': '生物识别',
      'biometric_enabled_desc': '使用指纹或面容解锁',
      'auto_lock_time': '自动锁定',
      'auto_lock_time_desc': '设置自动锁定时间',
      'databases': '数据库',

      'show_website_icons': '显示网站图标',
      'show_website_icons_desc': '在密码列表中显示网站图标',
      'backup': '备份',
      'backup_desc': '备份您的数据',
      'recover': '恢复',
      'recover_desc': '从备份恢复数据',
      'sync': '同步',
      'sync_desc': '配置云同步设置',
      'theme_mode': '深色模式',
      'theme_mode_desc': '切换深色/浅色主题',
      'layout_mode': '布局模式',
      'layout_mode_desc': '切换手机布局/电脑布局',
      'language': '语言',
      'language_desc': '更改应用语言',
      'about': '关于',
      'about_app': '关于应用',
      'about_app_desc': '版本和许可信息',
      'help': '帮助',
      'help_desc': '获取帮助和支持',
      'appearance': '外观',
      'data_management': '数据管理',
      'privacy_settings': '隐私设置',
      "erase_data": '抹除数据',
      "erase_local_data": '抹除本地数据',
      "erase_local_data_desc": '将删除所有本地保存的密钥、加密数据、内部保险库等。无法恢复，请谨慎操作!',

      'base': '基础',
      'history': '历史记录',
      'operate': '操作',

      'icon': '图标',
      'database_icon': '图标',
      'file': '文件',
      'UUID': 'UUID',
      "name": '名字',
      "desc": '描述',
      'historyMaxItems': '最大历史记录',
      'historyMaxSize': '最大历史大小(M)',
      "recycleBinEnabled": '使用回收站',
      "op_import_kdbx": '导入kdbx数据库',
      "op_import_kdbx_desc": '从其他的keepass数据库中导入条目',
      "op_lock_database": '锁定保险库',
      "op_lock_database_desc": '锁定保险库后需要重新验证才能查看条目',
      "op_delete_database": '删除保险库',
      "op_delete_database_desc": '如果是内部保险库，删除后将无法恢复。外部保险库则只是移除访问。',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
  String? getOrNull(String key) {
    return _localizedValues[locale.languageCode]?[key];
  }

  String translateText(String text) {
    if (!text.contains('\$(')) return text;

    final regex = RegExp(r'\$\(([^)]+)\)');
    return text.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      return get(key);
    });
  }
}