import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../models/field_type.dart';
import '../models/edit_model.dart';
import '../utils/password_utils.dart';
import '../utils/navigation_helper.dart';
import '../widgets/password_display.dart';
import '../widgets/icon_widget.dart';
// import '../services/item_list_service.dart';
import '../services/item_detail_service.dart';
import '../services/theme_service.dart';


class DetailPage extends ConsumerStatefulWidget {
  final Function(KdbxEntry)? onChanged; // 当保存的时候回调
  final Function(KdbxEntry)? onDeleted;
  const DetailPage({
    super.key,
    this.onChanged,
    this.onDeleted,
  });
  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  bool _showTitle = false;
  final Map<String, bool> _passwordVisibility = {};
  final ScrollController _scrollController = ScrollController();
  late ItemDetailService _itemDetailService;
  late KdbxEntry _kdbxEntry;
  late EditEntry _item;
  bool _isRecycleBinItem = false;
  bool _isEditable = false;

  @override
  void initState() {
    super.initState();
    _itemDetailService = ref.read(itemDetailServiceProvider);
    _scrollController.addListener(_onScroll);
    _itemDetailService.addListener(_onSelectedEntryChanged);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _itemDetailService.removeListener(_onSelectedEntryChanged);
    super.dispose();
  }

  void _loadItems(){
    setState(() {
      if (_itemDetailService.selectedEntry!=null) {
        _kdbxEntry = _itemDetailService.selectedEntry!;
        _item = EditEntry.fromDbEntry(_kdbxEntry);
        _isRecycleBinItem = _kdbxEntry.isInRecycleBin;
        _isEditable = !_kdbxEntry.db.isReadonly;
        _passwordVisibility.clear();
      }
    });
  }

  void _onSelectedEntryChanged() {
    _loadItems();
    // 重置滚动位置
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _startEditing() {
    NavigationHelper.navigateToDetailEdit(context, _kdbxEntry.parent!, _kdbxEntry,
      onChanged: (isSaved) async {
        if (widget.onChanged != null) {
          widget.onChanged!(_kdbxEntry);
        }
      }
    ).then((value) {
      _loadItems();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _showTitle = _scrollController.offset > 100; // 根据实际header高度调整
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutService = ref.read(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;
    if (isMobileLayout){
      return Scaffold(
        appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(context),
            ),
            title: _showTitle ? Text(_item.name) : null,
            actions: _buildActions(),
            elevation: _scrollController.hasClients && _scrollController.offset > 0 ? 4 : 0,
            shadowColor: Colors.black.withAlpha(25),
          ),
        body: _buildContent(context, isMobileLayout),
        bottomSheet: _isRecycleBinItem ? _buildDeletePrompt() : null,
      );
    }else{
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: _scrollController.hasClients && _scrollController.offset > 0 
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] 
                : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLocation(_item),
                Row(children:_buildActions()),
              ],
            ),
          ),
          Expanded(child: _buildContent(context, isMobileLayout)),
          if (_isRecycleBinItem) _buildDeletePrompt(),
        ],
      );
    }
  }

  List<Widget> _buildActions(){
    if (_isRecycleBinItem){
      return [];
    }else{
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _isEditable?
            TextButton(
              onPressed: _startEditing,
              child: const Text('编辑'),
            ):
            TextButton(
              onPressed: () => {},
              child: const Text('只读'),
            ),
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_horiz),
          itemBuilder: (context) => _buildEntryMenu(),
          position: PopupMenuPosition.under,
        )
      ];
    }
  }

  Widget _buildContent(context, bool isMobileLayout) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Column(children: [
          if (isMobileLayout) _buildLocation(_item),
          _buildHeader(context, _item),
          _buildMainGroup(_item),
          ..._buildGroups(_item),
          if (_item.notes.value.isNotEmpty) _buildNotes(_item),
          _buildTags(_item),
          _buildTimeInfo(),
        ]),
      )
    );
  }

  Widget _buildLocation(EditEntry item) {
    var folder = item.parent!;
    var folderIcon = folder.folderIcon;
    var folderName = folder.folderName;
    return Container(
      key: const ValueKey('location'),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Row(
        children: [
          InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            onTap: () => {},
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
              child: Row(
                children: [
                  folder.dbIcon(),
                  Text(folder.dbName),
                  // const Icon(Icons.arrow_drop_down),
                  // 竖线
                  SizedBox(width: 10),
                  // VerticalDivider(width: 100, color: Colors.red),
                  // Divider( height: 1, color: Color(0xFFEEEEEE)),
                  folderIcon(),
                  Text(folderName),
                  SizedBox(width: 5),
                  // const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, EditEntry item) {
    return Container(
      key: const ValueKey('header'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          KdbxIconWidget(entry:_kdbxEntry, size:60, shadow:true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_item.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                // DatabaseLabel(db: _item.db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry> _buildEntryMenu() {
    final localStorageService = ref.read(localStorageServiceProvider);
    var dbid = _item.parent?.db.dbid ?? "";
    bool isFavorite = localStorageService.isFavorite(dbid, _item.id);

    return [
      PopupMenuItem<String>(
        onTap: ()=>_onTapEntryMenuItem('favorite'),
        child: Row(
          children: [
            Icon(Icons.star_outline, color: isFavorite ? Colors.blue : null),
            const SizedBox(width: 8),
            Text(isFavorite ? '取消收藏' : '收藏'),
          ],
        ),
      ),
      if (_isEditable) PopupMenuItem<String>(
        onTap: ()=>_onTapEntryMenuItem('copy'),
        child: Row(
          children: [
            const Icon(Icons.copy_outlined),
            const SizedBox(width: 8),
            const Text('创建副本'),
          ],
        ),
      ),
      if (_isEditable) const PopupMenuDivider(),
      if (_isEditable) PopupMenuItem<String>(
        onTap: ()=>_onTapEntryMenuItem('delete'),
        child: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('删除', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _onTapEntryMenuItem(String menuKey) async {
    final localStorageService = ref.read(localStorageServiceProvider);

    var dbid = _item.parent?.db.dbid ?? "";
    bool isFavorite = localStorageService.isFavorite(dbid, _item.id);
    switch (menuKey) {
      case "favorite":
        if (isFavorite) {
          await localStorageService.removeFavorite(dbid, _item.id);
        } else {
          await localStorageService.addFavorite(dbid, _item.id);
        }
        setState(() {}); // 刷新界面
        break;
      case "copy":
        // TODO: 处理创建副本操作
        break;
      case "delete":
        _deleteOrRecycleEntry();
        break;
    }
  }

  void _deleteOrRecycleEntry() {
    final layoutService = ref.read(layoutServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);

    itemListService.deleteEntry(_kdbxEntry, true);

    if (layoutService.isMobileLayout){
      if (mounted) Navigator.pop(context);
    }else{
      setState(() {
        _isRecycleBinItem = _kdbxEntry.isInRecycleBin;
      });
      widget.onDeleted?.call(_kdbxEntry);
    }
  }

  // 彻底删除
  void _deleteEntry() {
    final layoutService = ref.read(layoutServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    itemListService.deleteEntry(_kdbxEntry, false);
    
    if (layoutService.isMobileLayout){
      if (mounted) Navigator.pop(context);
    }else{
      setState(() {
        _isRecycleBinItem = _kdbxEntry.isInRecycleBin;
      });
      widget.onDeleted?.call(_kdbxEntry);
    }
  }

  // 恢复
  void _recoverEntry() {
    final itemListService = ref.read(itemListServiceProvider);
    itemListService.recoverEntry(_kdbxEntry);
    setState(() {
      _isRecycleBinItem = _kdbxEntry.isInRecycleBin;
    });
  }


  Widget _buildTimeInfo() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        iconColor: Colors.grey[600],
        textColor: Colors.grey[600],
        initiallyExpanded: false,
        title: Text(
          '修改于 ${_formatDateTime(_item.modifiedAt)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              '创建于 ${_formatDateTime(_item.createdAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildGroups(EditEntry item) {
    List<Widget> groups = [];

    var defaultGroup = item.defaultGroup;
    var defaultGroupFields = defaultGroup.fields.where((f) => !EditEntry.isSystemName(f.name)).toList();
    groups.add(_buildOneGroup(defaultGroup, defaultGroupFields));

    for (var group in item.fieldGroups) {
      groups.add(_buildOneGroup(group, group.fields));
    }
    return groups;
  }

  Widget _buildMainGroup(EditEntry item) {
    var fs = item.defaultGroup.fields
        .where((f) => EditEntry.isSystemName(f.name) && f.name != "Notes")
        .toList();
    if (fs.isEmpty) {
      return SizedBox.shrink();
    }

    // 按照 UserName, Password, URL 排序
    fs.sort((a, b) {
      final fieldPriority = {
        'UserName': 1,
        'Password': 2,
        'URL': 3,
      };
      final priorityA = fieldPriority[a.name] ?? 999;
      final priorityB = fieldPriority[b.name] ?? 999;
      return priorityA.compareTo(priorityB);
    });

    int num = 0;
    List<Widget> children = [];
    for (var field in fs) {
      if (field.value.isEmpty) continue;
      if (num > 0) {
        children.add(Divider(height: 1));
      }
      children.add(_buildOneField('', field, fs.indexOf(field)));
      ++num;
    }
    // if (num==0){
    //   children.add(Text('无任何信息', style: TextStyle(color: Colors.grey, fontSize: 14)));
    // }

    return Container(
        padding: const EdgeInsets.all(0),
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
            // color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey,
              width: 1,
            )),
        // decoration: BoxDecoration(
        //   color: Theme.of(context).primaryColor,
        //   shape: BoxShape.circle,
        // ),
        child: Column(children: children));
  }

  Widget _buildNotes(EditEntry item) {
    return _buildOneField('', _item.notes, -1);
  }

  Widget _buildTags(EditEntry item) {
    List<String> tags = item.tags.toList();
    if (tags.isEmpty) {
      return SizedBox.shrink();
    }
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标签', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tags.map((tag) => Container(
                margin: const EdgeInsets.only(right: 4, bottom: 4),
                child: ActionChip(
                  label: Text(tag),
                  labelStyle: const TextStyle(fontSize: 13),
                  backgroundColor: themeExtension?.tagBackgroundColor,
                  // deleteIconColor: Colors.blue[700],
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  // padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    // print("ActionChip onPressed");
                  },
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOneGroup(EditFieldGroup group, List<EditFieldItem> fields) {
    String groupName = group.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        if (groupName.isNotEmpty) ListTile(
            title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold))
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields
              .map((field) => _buildOneField(groupName, field, fields.indexOf(field)))
              .toList(),
          ),
        ),
      ],
    );
  }

  // 添加菜单项构建方法
  List<PopupMenuEntry> _buildFieldMenuItems(EditFieldItem field) {
    final List<PopupMenuEntry> items = [];

    if (field.type == FieldType.url) {
      items.add(PopupMenuItem(
        child: Row(
          children: [
            const Text('打开  '),
            const Spacer(),
            const Icon(Icons.open_in_new),
          ],
        ),
        onTap: () => _onFieldOpenURL(field),
      ));
    }
    items.add(PopupMenuItem(
      child: Row(
        children: [
          const Text('复制  '),
          const Spacer(),
          const Icon(Icons.copy),
        ],
      ),
      onTap: () => _onFieldCopy(field),
    ));

    // 密码类型特有的"显示/隐藏"选项
    if (field.type == FieldType.password) {
      items.add(
        PopupMenuItem(
          child: Row(
            children: [
              const Text('显示/隐藏  '),
              const Spacer(),
              const Icon(Icons.visibility),
            ],
          ),
          onTap: () => _onFieldToggleVisibility(field),
        ),
      );
    }

    if (!_isRecycleBinItem) {
      final localStorageService = ref.read(localStorageServiceProvider);
      var dbid = _item.parent?.db.dbid ?? '';
      bool isQuickAccess =
          localStorageService.isQuickAccess(dbid, _item.id, field.name);
      items.add(PopupMenuItem(
        child: Row(
          children: [
            Text(isQuickAccess ? '取消快速访问' : '添加快速访问'),
            const Spacer(),
            Icon(isQuickAccess ? Icons.push_pin : Icons.push_pin_outlined),
          ],
        ),
        onTap: () async {
          if (isQuickAccess) {
            await localStorageService.removeQuickAccess(
                dbid, _item.id, field.name);
          } else {
            await localStorageService.addQuickAccess(dbid, _item.id, field.name);
          }
          setState(() {}); // 刷新界面
        },
      ));
    }

    return items;
  }

  // 添加新的处理方法
  void _onFieldToggleVisibility(EditFieldItem field) {
    setState(() {
      _passwordVisibility[field.name] =
          !(_passwordVisibility[field.name] ?? true);
    });
  }

  // 使用系统浏览器打开链接
  void _onFieldOpenURL(EditFieldItem field) async {
    final Uri url = Uri.parse(field.value);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开此链接'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onFieldCopy(EditFieldItem field) {
    _copyFieldValue(field);
  }

  Widget _buildOneField(String groupID, EditFieldItem field, int idx) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _copyFieldValue(field);
        },
        child: ListTile(
          key: ValueKey(field.name),
          title: Text(field.name,
              style: TextStyle(color: Colors.blue[700], fontSize: 14)),
          subtitle: _buildFieldValueNonEditing(groupID, field),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_horiz),
            itemBuilder: (context) => _buildFieldMenuItems(field),
            position: PopupMenuPosition.under,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldValueNonEditing(String groupID, EditFieldItem field) {
    switch (field.type) {
      case FieldType.password:
        final color = PasswordUtils.getStrengthColor2(field.value);
        return Row(
          children: [
            Expanded(
              child: PasswordDisplay(
                password: field.value,
                obscureText:
                    _passwordVisibility[field.name] ?? true, // 使用状态控制显示
              ),
            ),
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      default:
        return Text(field.value);
    }
  }

  Widget _buildDeletePrompt() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text('此条目已经在回收站中，您可以彻底删除或者恢复。',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onClickRecoverButton,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
                child: const Text('恢复条目'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onClickDeleteButton,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('彻底删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _copyFieldValue(EditFieldItem field) {
    final itemListService = ref.read(itemListServiceProvider);
    final itemDetailService = ref.read(itemDetailServiceProvider);
    // 复制字段值到剪贴板
    Clipboard.setData(ClipboardData(text: field.value));
    if (itemDetailService.addRecentSearchIfCopied) {
      itemListService.addRecentSearch(_kdbxEntry);
    }

    // 显示提示，先清除当前显示的消息
    ScaffoldMessenger.of(context)
      ..clearSnackBars() // 清除当前显示的所有消息
      ..showSnackBar(
        SnackBar(
          content: Text('已复制${field.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }


  void onClickRecoverButton(){
    // 恢复操作
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复项目'),
        content: const Text('确定要恢复此项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 执行恢复逻辑
              _recoverEntry();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void onClickDeleteButton(){
    // 永久删除操作
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除'),
        content: const Text('此操作不可撤销，确定要永久删除此项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 执行永久删除逻辑
              _deleteEntry();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
  }

}
