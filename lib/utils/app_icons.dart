import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';

class AppIcons {
  static final Map<KdbxIcon, IconData> _mapIcons = {
    KdbxIcon.key: Icons.key,
    KdbxIcon.world: Icons.public,
    KdbxIcon.warning: Icons.warning,
    KdbxIcon.networkServer: Icons.dns,
    KdbxIcon.markedDirectory: Icons.folder_special,
    KdbxIcon.userCommunication: Icons.chat,
    KdbxIcon.parts: Icons.build,
    KdbxIcon.notepad: Icons.note,
    KdbxIcon.worldSocket: Icons.power,
    KdbxIcon.identity: Icons.person,
    KdbxIcon.paperReady: Icons.description,
    KdbxIcon.digicam: Icons.camera_alt,
    KdbxIcon.irCommunication: Icons.wifi,
    KdbxIcon.multiKeys: Icons.vpn_key,
    KdbxIcon.energy: Icons.bolt,
    KdbxIcon.monitor: Icons.desktop_windows,
    KdbxIcon.eMail: Icons.email,
    KdbxIcon.configuration: Icons.settings,
    KdbxIcon.clipboardReady: Icons.content_paste,
    KdbxIcon.paperNew: Icons.note_add,
    KdbxIcon.screen: Icons.computer,
    KdbxIcon.eMailBox: Icons.mail_outline,
    KdbxIcon.disk: Icons.save,
    KdbxIcon.drive: Icons.storage,
    KdbxIcon.console: Icons.terminal,
    KdbxIcon.printer: Icons.print,
    KdbxIcon.programIcons: Icons.apps,
    KdbxIcon.run: Icons.play_arrow,
    KdbxIcon.settings: Icons.settings,
    KdbxIcon.archive: Icons.archive,
    KdbxIcon.homebanking: Icons.account_balance,
    KdbxIcon.clock: Icons.access_time,
    KdbxIcon.trashBin: Icons.delete,
    KdbxIcon.note: Icons.sticky_note_2,
    KdbxIcon.info: Icons.info,
    KdbxIcon.package: Icons.inventory_2,
    KdbxIcon.folder: Icons.folder,
    KdbxIcon.folderOpen: Icons.folder_open,
    KdbxIcon.folderPackage: Icons.folder_zip,
    KdbxIcon.lockOpen: Icons.lock_open,
    KdbxIcon.checked: Icons.check_circle,
    KdbxIcon.pen: Icons.edit,
    KdbxIcon.book: Icons.book,
    KdbxIcon.list: Icons.list,
    KdbxIcon.userKey: Icons.admin_panel_settings,
    KdbxIcon.tool: Icons.build_circle,
    KdbxIcon.home: Icons.home,
    KdbxIcon.star: Icons.star,
    KdbxIcon.money: Icons.attach_money,
    KdbxIcon.certificate: Icons.verified,
    KdbxIcon.scanner: Icons.scanner,
    KdbxIcon.wiki: Icons.menu_book,
    KdbxIcon.apple: Icons.apple,
  };
  static List<KdbxIcon> get allIcons => _mapIcons.keys.toList();

  static IconData getIcon(KdbxIcon icon) {
    return _mapIcons[icon] ?? Icons.key;
  }

  // static const IconData key = Icons.key;

  // // 安全相关图标
  // static const IconData security = Icons.security;
  // static const IconData lock = Icons.lock;
  // static const IconData lockOpen = Icons.lock_open;
  // static const IconData shield = Icons.shield;
  // static const IconData vpnKey = Icons.vpn_key;
  // static const IconData password = Icons.password;
  
  // // 用户设置相关图标
  // static const IconData settings = Icons.settings;
  // static const IconData accountCircle = Icons.account_circle;
  // static const IconData person = Icons.person;
  // static const IconData fingerprint = Icons.fingerprint;
  // static const IconData faceUnlock = Icons.face;
  // static const IconData darkMode = Icons.dark_mode;
  // static const IconData lightMode = Icons.light_mode;
  
  // // 数据相关图标
  // static const IconData backup = Icons.backup;
  // static const IconData restore = Icons.restore;
  // static const IconData sync = Icons.sync;
  // static const IconData cloudUpload = Icons.cloud_upload;
  // static const IconData cloudDownload = Icons.cloud_download;
  // static const IconData storage = Icons.storage;
  
  // // 通知和提醒相关图标
  // static const IconData notifications = Icons.notifications;
  // static const IconData timer = Icons.timer;
  // static const IconData alarm = Icons.alarm;
  
  // // 其他实用图标
  // static const IconData visibility = Icons.visibility;
  // static const IconData visibilityOff = Icons.visibility_off;
  // static const IconData edit = Icons.edit;
  // static const IconData delete = Icons.delete;
  // static const IconData share = Icons.share;
  // static const IconData copy = Icons.content_copy;
  // static const IconData language = Icons.language;
  // static const IconData help = Icons.help;
  // static const IconData info = Icons.info;
}