import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../models/field_type.dart';
import '../models/edit_model.dart';
import '../i18n/translations.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/colored_password_field.dart';
import '../widgets/folder_select_sheet.dart';
import '../widgets/icon_widget.dart';
import '../widgets/icon_selection_dialog.dart';
import '../services/theme_service.dart';
import '../services/icon_service.dart';

class DetailEditPage extends ConsumerStatefulWidget {
  final Function(bool) onChanged; // 当保存的时候回调

  const DetailEditPage({
    super.key,
    required this.onChanged,
  });
  @override
  ConsumerState<DetailEditPage> createState() => _DetailEditPageState();
}

class _DetailEditPageState extends ConsumerState<DetailEditPage> {
  late KdbxGroup _srcFolder;
  late KdbxEntry? _srcEntry;
  late bool _isNewItem;
  late EditEntry _item;
  late EditEntry _editingItem; // 添加编辑状态的临时数据
  var isShowWebsiteIcons = false;
  Timer? _urlDebounceTimer;

  @override
  void initState() {
    super.initState();

    final itemDetailService = ref.read(itemDetailServiceProvider);
    final localStorageService = ref.read(localStorageServiceProvider);

    isShowWebsiteIcons = localStorageService.getShowWebsiteIcons();

    _srcFolder = itemDetailService.editingParent!;
    _srcEntry = itemDetailService.editingEntry;
    _isNewItem = _srcEntry==null;

    if (_isNewItem) {
      // 新建
      _item = EditEntry.newEditEntry(_srcFolder);
      _editingItem = _item.clone();
      _editingItem.parent = _srcFolder;
    }else{
      // 编辑
      _item = EditEntry.fromKdbxEntry(_srcEntry!);
      _editingItem = _item.clone();
    }

    // EditFieldItem.test();

    if (isShowWebsiteIcons && !_isNewItem && _editingItem.opIcon==null) {
      _tryFetchIconFromUrlOnInit();
    }
  }

  @override
  void dispose() {
    _urlDebounceTimer?.cancel(); // 取消定时器
    super.dispose();
  }

  void _cancelEditing() {
    final itemDetailService = ref.read(itemDetailServiceProvider);
    itemDetailService.setEditingEntry(null,null);
    widget.onChanged(false);
  }

  void _saveEditing() {
    final itemDetailService = ref.read(itemDetailServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    if (_srcEntry!=null){
      if (_editingItem.toDbEntry(_srcEntry!)){
        itemListService.onEntryChanged(_srcEntry!);
      }
    }else{
      itemListService.addEntry(_editingItem);
    }
    itemDetailService.setEditingEntry(null,null);
    widget.onChanged(true);
  }

  void onDataChanged() {}

  @override
  Widget build(BuildContext context) {
    final layoutService = ref.watch(layoutServiceProvider);
    final isMobileLayout = layoutService.isMobileLayout;
    // final themeExtension = Theme.of(context).extension<AppThemeExtension>();

    if (isMobileLayout){
      return Scaffold(
        appBar: AppBar(
          elevation: 1,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          leading: _buildCancelButton(),
          leadingWidth: 96, // 增加leading区域宽度以容纳文字
          title: const Text('编辑'),
          centerTitle: true,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: _buildSaveButton(),
            )
          ]
        ),
        body: _buildEditView(context, _editingItem),
      );
    }else{
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCancelButton(),
                const Expanded(
                  child: Center(
                    child: Text('编辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
          ),
          Expanded(child: _buildEditView(context, _editingItem)),
        ],
      );
    }
  }

  Widget _buildCancelButton() {
    return TextButton.icon(
      icon: const Icon(Icons.arrow_back_ios),
      onPressed: _cancelEditing,
      label: const Text('取消'),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveEditing,
      child: const Text('保存'),
    );
  }

  Widget _buildLocation(EditEntry item) {
    var folder = _editingItem.parent??_srcFolder;
    var folderIcon = folder.folderIcon;
    var folderName = folder.folderName;
    return InkWell(
      onTap: _selectDatabaseAndFolder,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            folder.dbIcon(size:16, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              folder.dbName,
              style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              height: 16,
              width: 1,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 8),
            folderIcon(size: 16, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              folderName,
              style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EditEntry item) {
    return Container(
      key: const ValueKey('header'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 图标部分
          EditIconWidget(editEntry:item, size:60, shadow:true, onTap: () async {
            await _showIconSelector();
          }),
          const SizedBox(width: 16),
          // 标题部分
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: item.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    hintText: '输入标题',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.normal,
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 1.5),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    item.name = value;
                    onDataChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 新增方法：显示图标选择器
  Future<void> _showIconSelector() async {
    final newIcon = await IconSelectionDialog.show(
      context,
      selectedIcon: _editingItem.icon,
    );
    
    if (newIcon != null) {
      setState(() {
        _editingItem.icon = newIcon;
      });
      onDataChanged();
    }
  }
  
  void _selectDatabaseAndFolder() async {
    // var currentFolder = _itemService.getCurrentFolder();
    final folder = await FolderSelectSheet.show(
      context,
      initialFolder: _editingItem.parent,
      allowRoot: _isNewItem,
    );
    if (folder != null) {
      setState(() {
        _editingItem.parent = folder;
      });
      onDataChanged();
    }
  }

  Widget _buildEditView(BuildContext context, EditEntry item) {
    var defaultGroup = item.defaultGroup;
    var defaultGroupFields = defaultGroup.fields.where((f) => 
      !EditEntry.isSystemName(f.name) && 
      f.name != "Notes"
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
      children: [
        _buildLocation(_editingItem),
        // 顶部不可拖动部分 - 头部
        _buildHeader(context, _editingItem),

        // 系统属性分组（UserName, Password, URL）- 不可删除
        Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildSystemFields(item),
          ),
        ),

        // 默认分组
        _buildGroup(0, defaultGroup, defaultGroupFields),

        // 中间可拖动部分
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: _onReorderGroups,
          children: _buildGroups(item),
        ),

        // 添加分组按钮
        ListTile(
          key: const ValueKey('add_website'),
          leading: const Icon(Icons.add, color: Colors.blue),
          title: const Text('添加分组', style: TextStyle(color: Colors.blue)),
          onTap: () {
            _addGroupField();
          },
        ),

        // Notes 属性（始终放在最后）
        Card(
          key: const ValueKey('notes'),
          margin: const EdgeInsets.all(8),
          child: _buildField(item.defaultGroup, item.notes, -1),
        ),
        
        // 标签部分
        Card(
          key: const ValueKey('tags'),
          margin: const EdgeInsets.all(8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.label_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Text('标签', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      )
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildTagsSection(item),
            ],
          ),
        ),

        SizedBox(
          key: const ValueKey('--end--'),
          height: 16,
        ),
      ],
    ));
  }

  // 构建系统字段（UserName, Password, URL）
  List<Widget> _buildSystemFields(EditEntry item) {
    List<Widget> ret = [];
    var g = item.defaultGroup;
    ret.add(_buildSystemField(g, g.getField('UserName', FieldType.text), Icons.person_outline));
    ret.add(const Divider(height: 1, indent: 16, endIndent: 16));
    ret.add(_buildSystemField(g, g.getField('Password', FieldType.password), Icons.lock_outline));
    ret.add(const Divider(height: 1, indent: 16, endIndent: 16));

    var urlField = g.getField('URL', FieldType.url);
    if (isShowWebsiteIcons){
      ret.add(_buildSystemField(g, urlField, Icons.link, onValueChanged: (value) {
        _handleUrlChanged(value);
      }));
    }else{
      ret.add(_buildSystemField(g, urlField, Icons.link));
    }
    return ret;
  }

  // 新增：构建系统字段的美化版本
  Widget _buildSystemField(EditFieldGroup group, EditFieldItem field, IconData icon, {Function(String)? onValueChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListTile(
      leading: Icon(icon, color: Colors.blue[700], size: 22),
      title: Text(field.name,
          style: TextStyle(color: Colors.blue[700], fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: _buildFieldValueIsEditing(group, field, onValueChanged: onValueChanged),
    ));
  }

  // 处理 URL 变更
  void _handleUrlChanged(String url) {
    _urlDebounceTimer?.cancel();

    final normalizedUrl = IconService.normalizeUrl(url);
    if (IconService.canFetchIcon(normalizedUrl)) {
      _urlDebounceTimer = Timer(const Duration(milliseconds: 800), () {
        _tryFetchIconFromUrl(normalizedUrl); // 尝试获取图标
      });
    }
    onDataChanged();
  }

  // 首次进入页面时尝试获取图标
  void _tryFetchIconFromUrlOnInit() {
    // 如果未确定图标，则尝试根据URL获取一次
    final url = _editingItem.getValue('', 'URL')?.value;
    if (url!=null && url.isNotEmpty){
      final normalizedUrl = IconService.normalizeUrl(url);
      if (IconService.canFetchIcon(normalizedUrl)) {
        // 延迟一下，确保页面已经加载完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _tryFetchIconFromUrl(normalizedUrl);
          }
        });
      }
    }
  }

  // 尝试从 URL 获取图标，如果获取成功，就更新到 opIcon
  void _tryFetchIconFromUrl(String normalizedUrl) async {
    final iconService = ref.read(iconServiceProvider);
    try {
      final icon = await iconService.getIconFromUrl(normalizedUrl);
      print('_tryFetchIconFromUrl: $normalizedUrl');
      
      // 如果获取成功且组件仍在树中
      if (icon!=null && icon.iconId != null && icon.image != null) {
        if (context.mounted) {
          setState(() {
            _editingItem.opIcon = normalizedUrl;
          });
        }
      } else {
        // 获取失败，标记为失败 URL
        IconService.markFailedUrl(normalizedUrl);
      }
    } catch (e) {
      // 发生错误，标记为失败 URL
      IconService.markFailedUrl(normalizedUrl);
    }
  }

  String _formatDate(DateTime date) {
    String m = date.month >= 10 ? "${date.month}" : "0${date.month}";
    String d = date.day >= 10 ? "${date.day}" : "0${date.day}";
    return '${date.year}-$m-$d';
  }

  // 构建其他分组
  List<Widget> _buildGroups(EditEntry item) {
    List<Widget> groups = [];
    int idx = 0;
    for (var group in item.fieldGroups) {
      groups.add(_buildGroup(idx, group, group.fields));
      ++idx;
    }
    return groups;
  }
  Widget _buildGroup(int idx, EditFieldGroup group, List<EditFieldItem> fields) {
    bool notDefaultGroup = group.name.isNotEmpty;

    return Column(
      key: ValueKey(group.uid),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const SizedBox(width: 40),
        if (notDefaultGroup) ListTile(
          leading: IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            tooltip: '删除分组',
            onPressed: () => _removeGroup(group),
          ),
          title: TextFormField(
            initialValue: group.name,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.zero,
              isDense: true,
              border: InputBorder.none,
              hintText: '分组名称',
            ),
            onChanged: (value) {
              group.name = value;
              onDataChanged();
            },
          ),
          trailing: ReorderableDragStartListener(
            index: idx,
            child: const Icon(Icons.drag_handle,
                color: Colors.grey),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fields.isEmpty && notDefaultGroup)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('暂无字段，点击下方按钮添加',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                ),
              if (fields.isNotEmpty)
                _buildReorderableFields(group, fields),
              _buildAddFieldButton(group),
            ],
          ),
        )
      ]
    );
  }

  // 删除分组方法
  void _removeGroup(EditFieldGroup group) {
    setState(() {
      _editingItem.fieldGroups.remove(group);
    });
    onDataChanged();
  }

  Widget _buildReorderableFields(EditFieldGroup group, List<EditFieldItem> fields) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) =>
          _onReorderFields(fields, oldIndex, newIndex),
      children: fields
          .map((field) => Column(
            key: ValueKey(field.uid),
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              _buildField(group, field, fields.indexOf(field)),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ]),
          )
          .toList(),
    );
  }

  Widget _buildField(EditFieldGroup group, EditFieldItem field, int orderIdx) {
    if (orderIdx >= 0) {
      // 可编辑可拖动
      return ListTile(
        // key: ValueKey(field.uid),
        leading: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          tooltip: '删除字段',
          onPressed: () => _removeField(group.uid, field.uid),
        ),
        title: TextFormField(
          initialValue: field.name,
          style: TextStyle(color: Colors.blue[700], fontSize: 14, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.zero,
            isDense: true,
            border: InputBorder.none,
            hintText: '字段名称',
          ),
          onChanged: (value) {
            field.name = value;
            onDataChanged();
          },
        ),
        subtitle: _buildFieldValueIsEditing(group, field),
        // trailing: ReorderableDragStartListener(
        //   index: orderIdx,
        //   child: const Icon(Icons.drag_handle, color: Colors.grey),
        // ),
      );
    } else {
      // 标题只读，不允许改变顺序
      return ListTile(
        key: ValueKey(field.uid),
        leading: const SizedBox(width: 40),
        title: Text(field.name,
            style: TextStyle(color: Colors.blue[700], fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: _buildFieldValueIsEditing(group, field),
        trailing: const SizedBox(width: 40),
      );
    }
  }

  Widget _buildFieldValueIsEditing(EditFieldGroup group, EditFieldItem field, {Function(String)? onValueChanged}) {
    switch (field.type) {
      case FieldType.date:
        return InkWell(
          onTap: () async {
            DateTime? dt = DateTime.tryParse(field.value);
            final date = await showDatePicker(
              context: context,
              initialDate: dt ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                field.value = _formatDate(date);
              });
              onDataChanged();
              onValueChanged?.call(field.value);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Text(field.value.isEmpty ? '选择日期' : field.value),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        );

      case FieldType.password:
        return StatefulBuilder(
          builder: (context, setState) => Row(
            children: [
              Expanded(
                child: ColoredPasswordField(
                  password: field.value,
                  onChanged: (value) {
                    field.value = value;
                    onDataChanged();
                    onValueChanged?.call(value);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.password),
                onPressed: () {
                  _showPasswordDialog(group, field);
                },
              ),
            ],
          ),
        );

      case FieldType.multilineText:
        return TextFormField(
          initialValue: field.value,
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
          onChanged: (value) {
            field.value = value;
            onDataChanged();
            onValueChanged?.call(value);
          },
        );

      default:
        return TextFormField(
          initialValue: field.value,
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
          onChanged: (value) {
            field.value = value;
            onDataChanged();
            onValueChanged?.call(value);
          },
        );
    }
  }

  Future<void> _showPasswordDialog(EditFieldGroup group, EditFieldItem field) async {
    final generatedPassword = await PasswordGeneratorDialog.show(context);
    if (generatedPassword != null) {
      setState(() {
        field.value = generatedPassword;
      });
      onDataChanged();
    }
    // showDialog(
    //   context: context,
    //   builder: (context) => PasswordGeneratorDialog(
    //     onGenerated: (password) {
    //       setState(() {
    //         field.value = password;
    //       });
    //       onDataChanged();
    //     },
    //   ),
    // );
  }

  void _onReorderFields(List<EditFieldItem> fields, int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = fields.removeAt(oldIndex);
      fields.insert(newIndex, item);
    });
    onDataChanged();
  }

  void _removeField(int groupUid, int fieldUid) {
    setState(() {
      // 根据id删除字段
      _editingItem.removeValue(groupUid, fieldUid);
    });
    onDataChanged();
  }

  
  // 构建标签部分
  Widget _buildTagsSection(EditEntry item) {
    // 获取当前项目的标签列表
    List<String> tags = item.tags.toList();
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签显示区域
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tags.map((tag) => _buildTagChip(tag, themeExtension)),
              // 添加标签按钮
              OutlinedButton.icon(
                icon: Icon(Icons.add),
                label: Text('添加标签'),
                onPressed: _showAddTagDialog,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          
          // 如果没有标签，显示提示信息
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '添加标签可以更好地组织和查找您的项目',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
  
  // 构建单个标签
  Widget _buildTagChip(String tag, AppThemeExtension? theme) {
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      child: Chip(
        label: Text(tag),
        labelStyle: const TextStyle(fontSize: 13),
        backgroundColor: theme?.tagBackgroundColor,
        deleteIconColor: Colors.blue[700],
        onDeleted: () => _removeTag(tag),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
  
  // 显示添加标签对话框
  void _showAddTagDialog() {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标签名称',
              hintText: '输入标签名称',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '标签名称不能为空';
              }
              if (_editingItem.tags.contains(value.trim())) {
                return '标签已存在';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _addTag(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
  
  // 添加标签
  void _addTag(String tag) {
    setState(() {
      _editingItem.tags.add(tag);
    });
    onDataChanged();
  }
  
  // 删除标签
  void _removeTag(String tag) {
    setState(() {
      _editingItem.tags.remove(tag);
    });
    onDataChanged();
  }

  Widget _buildAddFieldButton(EditFieldGroup group) {
    final t = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      position: PopupMenuPosition.under,
      onSelected: (String value) {
        if (value == 'group') {
          _addGroupField();
        } else if (value == 'attachment') {
          _addAttachmentField(group);
        } else if (value == 'link') {
          _addLinkField(group);
        } else {
          _addAnyField(group, value);
        }
      },
      itemBuilder: (context) => [
        _buildMenuItem(t, 'security_question', Icons.security),
        _buildMenuItem(t, 'text', Icons.text_fields),
        _buildMenuItem(t, 'url', Icons.link),
        _buildMenuItem(t, 'email', Icons.email),
        _buildMenuItem(t, 'address', Icons.location_city),
        _buildMenuItem(t, 'date', Icons.date_range),
        _buildMenuItem(t, 'otp', Icons.one_k),
        _buildMenuItem(t, 'password', Icons.password),
        _buildMenuItem(t, 'phone', Icons.phone),
        _buildMenuItem(t, 'login', Icons.login),
        // _buildMenuItem(t, 'group', Icons.link),
        _buildMenuItem(t, 'attachment', Icons.attachment),
        _buildMenuItem(t, 'link', Icons.link),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(8,0,0,0),
        child: ListTile(
          leading: const Icon(Icons.add, color: Colors.blue),
          title: Text(t.get('add_field'),
              style: const TextStyle(color: Colors.blue)),
        ),
      ),
    );
  }
  PopupMenuItem<String> _buildMenuItem(AppLocalizations translations, String key, IconData icon) {
    return PopupMenuItem(
      value: key,
      //child: Text(translations.get(key))
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Text(translations.get(key)),
        ],
      )
    );
  }

  void _addGroupField() {
    // 添加一个新的分组，组名默认为空
    setState(() {
      _editingItem.fieldGroups.add(EditFieldGroup.create(name: "新分组"));
    });
    onDataChanged();
  }

  void _addAnyField(EditFieldGroup group, String keyName) {
    // 使用 Future.delayed 确保在当前帧渲染完成后再更新状态
    Future.delayed(Duration.zero, () {
      setState(() {
        final fieldType = FieldType.values.firstWhere((e) => e.name == keyName);
        group.getField(keyName, fieldType);
      });
      onDataChanged();
    });
  }

  void _addAttachmentField(EditFieldGroup group) {
    // 处理添加附件字段
  }
  void _addLinkField(EditFieldGroup group) {
    // 处理添加链接字段
  }

  void _onReorderGroups(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final group = _editingItem.fieldGroups.removeAt(oldIndex);
      _editingItem.fieldGroups.insert(newIndex, group);
    });
  }


}
