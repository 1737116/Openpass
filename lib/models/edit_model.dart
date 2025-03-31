import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'field_type.dart';
import 'package:kpasslib/kpasslib.dart';
import 'database_model.dart';

class EditUid {
  static final EditUid _instance = EditUid._internal();
  factory EditUid() => _instance;
  EditUid._internal();

  int _lastId = 0;

  int generateId() {
    _lastId++;
    return _lastId;
  }
}

class _EditGroupField {
  final String name;
  final KdbxTextField field;

  _EditGroupField({
    required this.name,
    required this.field,
  });
}

class EditFieldItem {
  int uid;
  late String name;
  late FieldType type;
  String value;

  String get fullname => makeFullname(name, type);
  bool get isProtected => type == FieldType.password;

  EditFieldItem({
    required this.uid,
    required this.name,
    required this.type,
    required this.value,
  });

  EditFieldItem.create({
    required this.name,
    required this.value,
    required this.type,
  }) : uid = EditUid().generateId();

  // 输入完整名字，构造结构体
  static EditFieldItem createFullname(String fullname, String value) {
    var (name, type) = splitFullname(fullname);
    return EditFieldItem(
      uid: EditUid().generateId(),
      name: name,
      type: type,
      value: value,
    );
  }

  static FieldType defaultTypeFromName(String fieldName) {
    if (fieldName == 'Password') {
      return FieldType.password;
    } else if (fieldName == 'URL') {
      return FieldType.url;
    } else if (fieldName == 'Notes') {
      return FieldType.multilineText;
    } else {
      return FieldType.text;
    }
  }

  // 输入显示的名字，返回完整名字
  static String makeFullname(String name, FieldType type) {
    var t2 = defaultTypeFromName(name);
    if (t2 == type) {
      if (name.isNotEmpty && name[0] == '[') {
        return '[$name';
      }
      return name;
    }
    return "[${FieldTypeHelper.fromType(type)}]$name";
  }

  static (String, FieldType) splitFullname(String fullname) {
    if (fullname.isNotEmpty && fullname[0] == '[') {
      if (fullname.length >= 2 && fullname[1] == '[') {
        return (fullname.substring(1), FieldType.text);
      } else {
        int pos = fullname.indexOf(']');
        if (pos >= 0) {
          String typeStr = fullname.substring(1, pos);
          String name = fullname.substring(pos + 1);
          FieldType t = FieldTypeHelper.fromString(typeStr);
          return (name, t);
        }
      }
    }
    return (fullname, defaultTypeFromName(fullname));
  }

  // 检查完整名字是否匹配类型，如果不匹配，则修正
  static String checkFieldType(String fullname, FieldType type) {
    var (name, t) = splitFullname(fullname);
    if (t == type) return fullname;
    return makeFullname(name, type);
  }

  static void test() {
    _case("01", checkFieldType("Password", FieldType.password), "Password");
    _case("03", checkFieldType("Password", FieldType.multilineText),
        "[~]Password");

    _caseSplit("10", "Password", FieldType.password);
    _caseSplit("11", "Password", FieldType.text);
    _caseSplit("12", "Password", FieldType.multilineText);
    _caseSplit("13", "Username", FieldType.text);
    _caseSplit("14", "Username", FieldType.password);
    _caseSplit("15", "Username", FieldType.email);
    _caseSplit("16", "Other", FieldType.text);
    _caseSplit("17", "Other", FieldType.password);
    _caseSplit("18", "Other", FieldType.email);
  }

  static void _caseSplit(String msg, String name, FieldType type) {
    final fullname = makeFullname(name, type);
    final (n2, t2) = splitFullname(fullname);
    if (n2 != name || t2 != type) {
      print("error $msg");
    }
  }

  static void _case(String msg, String n1, String n2) {
    if (n1 != n2) {
      print("error $msg");
    }
  }
}

class EditFieldGroup {
  int uid;
  String name;
  List<EditFieldItem> fields;

  EditFieldGroup({
    required this.uid,
    required this.name,
    required this.fields,
  });
  EditFieldGroup.create({
    required this.name,
  })  : uid = EditUid().generateId(),
        fields = [];

  EditFieldGroup clone(bool isDefaultGroup) {
    return EditFieldGroup(
        uid: isDefaultGroup ? 0 : EditUid().generateId(),
        name: name,
        fields: fields
            .map((f) => EditFieldItem(
                  uid: EditUid().generateId(),
                  name: f.name,
                  type: f.type,
                  value: f.value,
                ))
            .toList());
  }

  EditFieldItem getField(String fieldName, FieldType fieldType) {
    var f = fields.firstWhereOrNull((i) => i.name == fieldName);
    if (f != null) {
      return f;
    }
    f = EditFieldItem.create(name: fieldName, value: '', type: fieldType);
    fields.add(f);
    return f;
  }

  void set(String key, String val, FieldType t) {
    var f = fields.firstWhereOrNull((i) => i.name == key);
    if (f != null) {
      f.value = val;
    } else {
      fields.add(EditFieldItem.create(name: key, value: val, type: t));
    }
  }

  static EditFieldGroup newDefault(bool isDefaultGroup) {
    return EditFieldGroup(
        uid: isDefaultGroup ? 0 : EditUid().generateId(),
        name: '',
        fields: [
          EditFieldItem.create(
              name: 'UserName', value: "", type: FieldType.text),
          EditFieldItem.create(
              name: 'Password', value: "", type: FieldType.password),
          EditFieldItem.create(name: 'URL', value: "", type: FieldType.url),
          EditFieldItem.create(
              name: 'Notes', value: "", type: FieldType.multilineText),
        ]);
  }
}

class EditEntry {
  final String id; // uuid，空表示新建的
  KdbxGroup? parent;
  String name;
  String? customIcon;
  String? opIcon;
  KdbxIcon? icon;
  DateTime modifiedAt;
  DateTime createdAt;
  DateTime? expiredAt;
  // customData
  Set<String> tags = {};
  String? background; // The entry background color
  String? foreground; // The entry foreground color

  final EditFieldGroup defaultGroup;
  List<EditFieldGroup> fieldGroups;

  EditFieldItem get notes =>
      defaultGroup.getField('Notes', FieldType.multilineText);

  EditEntry({
    required this.id,
    required this.name,
    required this.modifiedAt,
    required this.createdAt,
    this.parent,
    this.expiredAt,
    this.customIcon,
    this.opIcon,
    this.icon,
    required this.defaultGroup,
    required this.fieldGroups,
    this.background,
    this.foreground,
    Set<String>? tagSet,
  }) : tags = tagSet ?? {};

  Color getBackground() {
    if (background != null) {
      return Color(int.parse(background!));
    }
    return Colors.white;
  }

  // Widget getEditorIcon(BuildContext context, {double size = 24.0}) {
  //   return IconHelper.buildIcon2(context, this, size: size);
  // }

  String getUsername() {
    for (var field in defaultGroup.fields) {
      if (field.name == 'UserName') {
        return field.value;
      }
    }
    return "";
  }

  static bool isSystemName(String name) {
    return name == 'Title' ||
        name == 'UserName' ||
        name == 'Password' ||
        name == 'URL' ||
        name == 'Notes';
  }

  EditFieldItem? getValue(String groupName, String fieldName) {
    if (groupName == "") {
      return defaultGroup.fields.firstWhereOrNull((i) => i.name == fieldName);
    } else {
      return fieldGroups
          .firstWhereOrNull((g) => g.name == groupName)
          ?.fields
          .firstWhereOrNull((i) => i.name == fieldName);
    }
  }

  void removeValue(int groupUid, int fieldUid) {
    if (groupUid == 0) {
      var f = defaultGroup.fields.firstWhereOrNull((i) => i.uid == fieldUid);
      if (f != null) {
        if (isSystemName(f.name)) {
          f.value = "";
        } else {
          defaultGroup.fields.remove(f);
        }
      }
    } else {
      final g = fieldGroups.firstWhereOrNull((g) => g.uid == groupUid);
      if (g == null) return;
      g.fields.removeWhere((f) => f.uid == fieldUid);
    }
  }

  EditEntry clone() {
    return EditEntry(
      id: id,
      name: name,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parent: parent,
      expiredAt: expiredAt,
      customIcon: customIcon,
      opIcon: opIcon,
      icon: icon,
      defaultGroup: defaultGroup.clone(true),
      fieldGroups: fieldGroups.map((g) => g.clone(false)).toList(),
      // modifiedAt: modifiedAt,
      // createdAt: createdAt,
      // expiredAt: expiredAt,
      // customIcon: customIcon,
      // icon: icon,
      background: background,
      foreground: foreground,
      tagSet: tags,
    );
  }

  // void sortFieldGroups(String orderStr) {
  //   try {
  //     final orderList = jsonDecode(orderStr) as List<String>;
  //   } catch (e) {
  //     print(e.toString());
  //   }
  // }

  // 格式：
  // * 使用 '.' 分割组名和字段名
  // * 字段名如果以两个左中括号开头，就去掉一个左中括号，余下是字段名
  // * 字段名如果以一个左中括号开头，那么括号内容就是类型（具体请看FieldType）
  static String makeFieldKey(String groupName, String fieldName) {
    if (groupName.isEmpty) {
      return fieldName.replaceAll('.', '\\.').replaceAll('\\', '\\\\');
    }
    groupName = groupName.replaceAll('.', '\\.');
    fieldName = fieldName.replaceAll('.', '\\.');
    // if (fieldName.isNotEmpty && fieldName[0]=='[') {
    //   fieldName = '[$fieldName';
    // }
    return "$groupName.$fieldName".replaceAll('\\', '\\\\');
  }

  static (String, String) splitFieldKey(String text) {
    String key = "";
    StringBuffer group = StringBuffer();
    int i = 0;
    while (i < text.length) {
      if (text[i] == '\\' && i + 1 < text.length) {
        group.write(text[++i]);
      } else if (text[i] == '.') {
        key = group.toString();
        group.clear();
      } else {
        group.write(text[i]);
      }
      i++;
    }
    String val = group.toString();
    return (key, val);
  }

  static EditEntry fromDbEntry(KdbxEntry src) {
    return fromKdbxEntry(src);
  }

  static EditEntry fromKdbxEntry(KdbxEntry kdbxEntry) {
    // 获取排序
    String? orderStr = kdbxEntry.getCustomValue('op_order');
    List<String> orderList = [];
    if (orderStr != null) {
      try {
        var arr = jsonDecode(orderStr) as List;
        for (var a in arr) {
          if (a is String) {
            orderList.add(a);
          }
        }
      } catch (e) {
        print(e.toString());
      }
    }
    // if (orderList.isEmpty){
    //   orderList = ['UserName','Password','URL'];
    // }

    // 获取根据顺序排列的列表
    List<_EditGroupField> allFields = [];
    Map<String, KdbxTextField> fields = {};
    kdbxEntry.fields.forEach((a, b) => fields[a] = b);
    for (var key in orderList) {
      if (fields.containsKey(key)) {
        allFields.add(_EditGroupField(name: key, field: fields[key]!));
        fields.remove(key);
      }
    }
    for (var key in fields.keys.toList()) {
      allFields.add(_EditGroupField(name: key, field: fields[key]!));
    }

    // 转换
    Map<String, EditFieldGroup> groupMap = {};
    List<EditFieldGroup> groupList = [];
    String title = "";
    for (var kv in allFields) {
      var key = kv.name;
      var val = kv.field;
      if (key == "Title") {
        title = val.text;
      } else {
        var (groupName, fieldFullName) = splitFieldKey(key);
        if (!groupMap.containsKey(groupName)) {
          var g = EditFieldGroup(
              uid: EditUid().generateId(), name: groupName, fields: []);
          groupMap[groupName] = g;
          if (groupName.isNotEmpty) {
            groupList.add(g);
          }
        }
        if (val is ProtectedTextField) {
          fieldFullName =
              EditFieldItem.checkFieldType(fieldFullName, FieldType.password);
        }

        EditFieldItem f = EditFieldItem.createFullname(fieldFullName, val.text);
        groupMap[groupName]!.fields.add(f);
      }
    }

    EditFieldGroup defaultGroup =
        groupMap[''] ?? EditFieldGroup.newDefault(true);
    groupMap.remove('');

    EditEntry e = EditEntry(
      parent: kdbxEntry.parent,
      id: kdbxEntry.uuid.string,
      name: title,
      modifiedAt: kdbxEntry.times.modification.timeOrZero,
      createdAt: kdbxEntry.times.creation.timeOrZero,
      expiredAt: kdbxEntry.times.expiry.time,
      icon: kdbxEntry.icon,
      defaultGroup: defaultGroup,
      fieldGroups: groupList.toList(),
    );

    e.opIcon = kdbxEntry.getCustomValue('op_icon');
    
    // 读取标签
    if (kdbxEntry.tags!=null && kdbxEntry.tags!.isNotEmpty) {
      e.tags = kdbxEntry.tags!.toSet();
    }
    return e;
  }

  bool toDbEntry(KdbxEntry tar) {
    // 数据收集
    List<String> orderList = [];
    Map<String, EditFieldItem> allFields = {};
    for (var field in defaultGroup.fields) {
      if (field.value.isNotEmpty) {
        var gfn = makeFieldKey("", field.fullname);
        allFields[gfn] = field;
        if (!isSystemName(field.name)) {
          orderList.add(field.name);
        }
      }
    }
    for (var group in fieldGroups) {
      for (var field in group.fields) {
        if (field.value.isNotEmpty) {
          var gfn = makeFieldKey(group.name, field.fullname);
          allFields[gfn] = field;
          orderList.add(gfn);
        }
      }
    }

    bool isChanged = false;

    // 删除所有多余的
    for (var field in tar.fields.keys.toList()) {
      if (!allFields.containsKey(field) && field != 'Title') {
        tar.fields.remove(field);
        isChanged = true;
      }
    }

    // 更新所有变化的
    for (var field in allFields.entries) {
      if (tar.fields.containsKey(field.key)) {
        var tarField = tar.fields[field.key]!;
        if (tarField.text != field.value.value) {
          tar.fields[field.key] = KdbxTextField.fromText(
              text: field.value.value, protected: field.value.isProtected);
          isChanged = true;
        }
      } else {
        tar.fields[field.key] = KdbxTextField.fromText(
            text: field.value.value, protected: field.value.isProtected);
        isChanged = true;
      }
    }

    // 修改Title
    var titleField = tar.fields['Title']?.text ?? '';
    if (titleField != name) {
      tar.fields['Title'] = KdbxTextField.fromText(text: name);
      isChanged = true;
    }

    // icon

    // 标签
    var tarTag = tar.tags?.toSet()?? {};
    bool isTagChanged = false;
    if (tarTag.length!=tags.length){
      isTagChanged = true;
    } else {
      for (var tag in tags) {
        if (!tarTag.contains(tag)){
          isTagChanged = true;
          break;
        }
      }
    }
    if (isTagChanged){
      if (tags.isNotEmpty) {
        tar.tags = tags.toList();
      } else {
        tar.tags = null;
      }
      isChanged = true;
    }

    // 保存字段顺序
    if (tar.setCustomValue('op_order', jsonEncode(orderList))) {
      isChanged = true;
    }

    var newIcon = icon??KdbxIcon.key;
    if (tar.icon!=newIcon) {
      tar.icon = newIcon;
      isChanged = true;
    }

    // 保存自定义图标
    if (tar.setCustomValue('op_icon', opIcon)) {
      isChanged = true;
    }

    // 父节点变化
    if (tar.parent!=null && parent!=null && tar.parent!=parent){
      if (tar.parent!.db==parent!.db && tar.db.kdbx!=null){
        tar.db.kdbx!.move(item: tar, target: parent);
        isChanged = true;
      }
    }

    if (isChanged) {
      tar.times.touch();
    }
    return isChanged;
  }

  static EditEntry newEditEntry(KdbxGroup parentFolder) {
    EditEntry e = EditEntry(
        parent: parentFolder,
        id: "",
        name: "新项目",
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        expiredAt: null,
        icon: null,
        defaultGroup: EditFieldGroup.newDefault(true),
        fieldGroups: []);
    return e;
  }
}
