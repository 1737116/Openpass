import 'package:uuid/uuid.dart';

class DatabaseInfo {
  final String id;
  final String filePath;
  String? dbIcon;
  String? name; // 数据库名字
  String? password; // 如果选择了保存密码，会有值
  String? keyData;
  final DateTime createdAt;

  DatabaseInfo({
    String? id,
    required this.filePath,
    this.name,
    this.password,
    this.keyData,
    this.dbIcon,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'name': name,
        'icon': dbIcon,
        'password': password,
        'keyData': keyData,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DatabaseInfo.fromJson(Map<String, dynamic> json) => DatabaseInfo(
        id: json['id'],
        filePath: json['filePath'],
        name: json['name'],
        dbIcon: json['icon'],
        password: json['password'],
        keyData: json['keyData'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
