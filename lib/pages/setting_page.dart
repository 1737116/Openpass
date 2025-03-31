import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/providers.dart';
import 'base_page.dart';
import '../routes/app_router.dart';
import '../models/database_model.dart';
import '../models/setting_item.dart';
import '../pages/import_kdbx_database_page.dart';
import '../i18n/translations.dart';
import '../widgets/theme_switch.dart';
import '../widgets/layout_switch.dart';
import '../widgets/master_password_dialog.dart';
import '../widgets/dbicon_selection_dialog.dart';
import '../widgets/vault_icon_widget.dart';


class SettingPage extends BasePage {
  final Function()? onRefreshSidebar;

  const SettingPage({
    super.key, 
    required super.onSwitchPage,
    this.onRefreshSidebar,
  });

  @override
  BasePageState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends BasePageState<SettingPage> with TickerProviderStateMixin {
  final TextEditingController _editController = TextEditingController();
  late SettingManager _settingManager;
  late SettingTreeItem _currentNode;
  late SettingTreeItem? _backupNode;
  OPDatabase? _inDatabase;
  final Map<String, AnimationController> _copyAnimationControllers = {};
  final ScrollController _scrollController = ScrollController();
  final List<double> _scrollPositions = [];
  String _appIcon = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
    final localStorageService = ref.read(localStorageServiceProvider);
    _settingManager = localStorageService.settings;
  }

  @override
  void dispose() {
    for (var controller in _copyAnimationControllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final localStorageService = ref.read(localStorageServiceProvider);
    _appIcon = localStorageService.getAppIcon();
    var root = localStorageService.settings.root;
    setCurrentNode(root, true, refreshParent: false);
  }
  
  @override
  Widget buildTitle() {
    return Row(
      children: [
        // const Icon(Icons.watch, size: 30),
        VaultIconWidget(iconName:_appIcon, size: 20),
        const SizedBox(width: 8),
        Text(getTitleName()),
      ],
    );
  }
  String getTitleName(){
    String title = '设置';
    if (_inDatabase!=null){
      title = _inDatabase!.name;
      if (_currentNode.parent!=null){
        title = '$title - ${_currentNode.name(AppLocalizations.of(context))}';
      }
    }else{
      if (_currentNode.parent!=null){
        title = _currentNode.name(AppLocalizations.of(context));
      }
    }
    return title;
  }
  
  @override
  List<Widget> buildActions() {
    return [
      ThemeSwitch(),
      SizedBox(width: 8),
      LayoutSwitch(),
      SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () {
          var localStorageService = ref.read(localStorageServiceProvider);
          localStorageService.lock();
          AppRouter().navigateTo(context, AppPage.login);
        },
      ),
    ];
  }
  
  @override
  bool showBackButton() => _currentNode != _settingManager.root || _inDatabase != null;

  @override
  void onBackPressed() {
    if (_currentNode.parent != null) {
      setCurrentNode(_currentNode.parent!, false);
      return;
    }else{
      if (_inDatabase!=null && _backupNode!=null) {
        setCurrentNode(_backupNode!, false);
        _inDatabase = null;
        _backupNode = null;
        return;
      }
    }
    widget.onSwitchPage?.call(0);
  }
  
  void setCurrentNode(SettingTreeItem  cur, bool isIn, {bool refreshParent=true}){
    double? scrollPosition;
    if (isIn){
      // 保存当前页面的滚动位置
      if (refreshParent && _scrollController.hasClients) {
        _scrollPositions.add(_scrollController.offset);
      }
    }else{
      // 返回上次位置
      scrollPosition = _scrollPositions.isNotEmpty?_scrollPositions.removeLast():null;
    }

    setState(() {
      _currentNode = cur;
    });

    // 在下一帧恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (scrollPosition!=null){
          _scrollController.jumpTo(scrollPosition);
        }else{
          _scrollController.jumpTo(0);
        }
      }
    });

    if (refreshParent){
      widget.onSwitchPage?.call(null);
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final layoutService = ref.watch(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;
    final translations = AppLocalizations.of(context);
    return Column(
      children: [
        if (!isMobileLayout)
          _buildSettingTitleBar(),
        // Padding(
        //   padding: const EdgeInsets.all(16.0),
        //   child: const CommonSearchBar(),
        // ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            children: _buildSettingItems(context, translations),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
                spreadRadius: 1,
              )
            ],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: onBackPressed,
        ),
        Expanded(child:Text(getTitleName())),
        ],
      ),
    );
  }

  Widget _buildDatabase(OPDatabase db) {
    return ListTile(
      leading: db.databaseIcon(),
      title: Text(db.name),
      subtitle: Text(
        db.dbInfo.filePath,
        style: const TextStyle(color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            db.isUnlocked ? '已解锁' : '已锁定',
            style: TextStyle(
              color: db.isUnlocked ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        if (db.isUnlocked){
          _inDatabase = db;
          _backupNode = _currentNode;
          if (_scrollController.hasClients) {
            _scrollPositions.add(_scrollController.offset);
          }
          setCurrentNode(_settingManager.dbRoot, true);
        }else{
          ScaffoldMessenger.of(context)
            ..clearSnackBars
            ..showSnackBar(
            SnackBar(
              content: Text('数据库未解锁'),
              duration: const Duration(seconds: 2),
            )
          );
        }
      },
    );
  }

  Widget _buildSettingControl(SettingItem item) {
    if(item.selectItems!=null){
      return DropdownButton<String>(
        value: item.value.toString(),
        items: item.selectItems!.map((SettingItemSelectItem kv) {
          return DropdownMenuItem<String>(
            value: kv.value,
            child: Text(kv.name),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue!= null) {
            if (item.type==SettingValueType.int){
              int? v = int.tryParse(newValue);
              if (v!=null){
                _onValueChanged(item, v);
              }
            }else if (item.type==SettingValueType.string){
              _onValueChanged(item, newValue);
            }
          }
        },
      );
    }else
    {
      switch (item.type) {
        case SettingValueType.bool:
          return Switch(
            value: item.value ?? false,
            onChanged: (value) async {
              await _onValueChanged(item, value);
            },
          );
        case SettingValueType.int:
          return Text('${item.value ?? 0}');
        case SettingValueType.string:
          return IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showTextEditDialog(item);
            },
          );
        case SettingValueType.func:
          return IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              item.value?.call();
            },
          );
      }
    }
  }

  Future<void> _onValueChanged(SettingItem item, dynamic v) async {
    var old = item.value;
    item.value = v;
    final localStorageService = ref.read(localStorageServiceProvider);
    if (!await localStorageService.onSettingItemChanged(item)) {
      item.value = old;
    }
    setState(() {});
  }

  void _showTextEditDialog(SettingItem item) {
    final controller = TextEditingController(text: item.value?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.key),
        content: TextField(
          controller: controller,
          // decoration: InputDecoration(hintText: item.desc),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _onValueChanged(item, controller.text);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.person, color: Colors.blue),
      ),
      title: const Text('数据同步设置', style: TextStyle(fontWeight: FontWeight.bold),),
      subtitle: const Text('数据同步可支持跨平台：Windows, iOS, 安卓', style: TextStyle(color: Colors.grey),),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: 导航到资料页面
      },
    );
  }

  Widget _buildSettingSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...items,
        const Divider(),
      ],
    );
  }

  Widget _buildSettingValue(BuildContext context, AppLocalizations translations, SettingTreeItem item) {
    String name = item.name(translations);
    String value = '';
    if (_inDatabase!=null){
      var db = _inDatabase!;
      if (item.key.isEmpty){
        // 只读
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(name, style: const TextStyle(fontSize: 12)),
            ),
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: ListTile(
                title: Text(value, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      }else{
        var kdbx = db.kdbx!;
        int editType = 0;
        switch (item.key)
        {
          case "name":
            value = db.name;
            editType = 2;
            break;
          case "desc":
            value = kdbx.meta.description??'';
            editType = 3;
            break;
          case 'historyMaxItems':
            value = (kdbx.meta.historyMaxItems??0).toString();
            editType = 5;
            break;
          case 'historyMaxSize':
            value = ((kdbx.meta.historyMaxSize??0)/(1024*1024)).floor().toString();
            editType = 5;
            break;
        }
        _editController.text = value;

        switch (editType) {
          case 2: // 单行文本
            return TextField(
              controller: _editController,
              decoration: InputDecoration(
                labelText: name,
                border: const OutlineInputBorder(),
              ),
            );
          case 3: // 多行文本
            return TextField(
              controller: _editController,
              maxLines: null,
              minLines: 8,
              decoration: InputDecoration(
                labelText: name,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            );
          case 5: // 数字输入
            return TextField(
              controller: _editController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,  // 只允许输入数字
              ],
              decoration: InputDecoration(
                labelText: name,
                border: const OutlineInputBorder(),
              ),
            );
          case 6: // 布尔值
            bool isChecked = _editController.text.toLowerCase() == 'true' || _editController.text == '1';
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: ListTile(
                title: Text(name),
                trailing: Switch(
                  value: isChecked,
                  onChanged: (bool value) {
                    setState(() {
                      _editController.text = value.toString();
                      setDbSetting(item.key, value.toString());
                    });
                  },
                ),
              ),
            );
        }
      }
    }else{

    }
    return const SizedBox();
  }

  Widget _buildAppSettingItem(BuildContext context, AppLocalizations translations, SettingTreeItem treeNode) {
    // 如果是通常的属性设置，就构造属性的显示节点
    SettingItem? settingNode = _settingManager.get(treeNode.key);
    if (settingNode!=null){
      return ListTile(
        leading: treeNode.icon!=null?Icon(treeNode.icon, color: Colors.blue):null,
        title: Text(treeNode.name(translations)),
        subtitle: Text(
          treeNode.desc(translations),
          style: const TextStyle(color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
        ),
        trailing: _buildSettingControl(settingNode),
      );
    }

    // 这里是属性设置中不存在的key，是用于自定义的界面
    switch (treeNode.key)
    {
      case ":profile":
        return _buildProfileSection();
      case "erase_local_data":
        return _buildButtonItem(context, translations, treeNode, onTap: () async {
          await _eraseLocalData(context);
        });
      default:
        {
          var title = treeNode.name(translations);
          var subtitle = treeNode.desc(translations);
          return ListTile(
            leading: Icon(treeNode.icon, color: Colors.blue),
            title: Text(title),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap : ()=>{
              if (!_onTapSettingItem(treeNode)) {
                setCurrentNode(treeNode, true)
              }
            }
          );
        }
    }
  }

  bool _onTapSettingItem(SettingTreeItem treeNode) {
    String key = treeNode.key;
    switch (key) {
      case 'nickname':
        _showNicknameDialog();
        return true;
      case 'app_icon':
        _showAppIconDialog();
        return true;
      case 'master_password':
        _showMasterPasswordDialog();
        return true;
      case 'master_key':
        _showMasterKeyDialog();
        return true;
      case 'sync_baidu':
        _showSyncBaiduDialog();
        return true;
    }
    return false;
  }

  Widget _buildButtonItem(BuildContext context, AppLocalizations translations, SettingTreeItem treeNode,{
    void Function()? onTap,
  }) {
    var title = treeNode.name(translations);
    var subtitle = treeNode.desc(translations);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(20,10,20,8),
            child: Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: treeNode.color,
              // foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onPressed: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(treeNode.icon),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 显示修改主密码对话框
  Future<void> _showMasterPasswordDialog() async {
    var localStorageService = ref.read(localStorageServiceProvider);
    
    if (!mounted) return;
    
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => MasterPasswordDialog(
        validateCurrentPassword: (currentPassword) async {
          return localStorageService.validateCurrentPassword(currentPassword);
        }
      ),
    );
    
    if (newPassword != null && newPassword.isNotEmpty) {
      // 更新主密码
      await localStorageService.changeMasterPassword(newPassword);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('主密码修改成功')),
        );
      }
    }
  }

  // 显示主密钥对话框
  Future<void> _showMasterKeyDialog() async {
    var appSettingsService = ref.read(appSettingsServiceProvider);
    var masterKey = await appSettingsService.getMasterKey();
    if (masterKey.isEmpty){
      masterKey = '[空]';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('查看主密钥'),
        content: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('您的主密钥为：'),
              const SizedBox(height: 8),
              Text(masterKey),
              const SizedBox(height: 16),
              Text('请妥善保存主密钥，一旦丢失将无法解密保险库', style: const TextStyle(color: Colors.grey),),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 显示修改昵称对话框
  Future<void> _showNicknameDialog() async {
    final localStorageService = ref.read(localStorageServiceProvider);
    String currentNickname = localStorageService.getNickname();
    
    final controller = TextEditingController(text: currentNickname);
    
    if (!mounted) return;
    
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: Container(
          width: 400,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 8),
              const Text(
                '昵称将显示在应用界面上，用于个性化您的体验',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (newNickname != null) {
      // 更新昵称
      await localStorageService.setNickname(newNickname);
      if (widget.onRefreshSidebar!=null) {
        widget.onRefreshSidebar!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称修改成功')),
        );
      }
    }
  }

  // 显示修改应用图标对话框
  Future<void> _showAppIconDialog() async {
    final localStorageService = ref.read(localStorageServiceProvider);
    String currentIcon = localStorageService.getAppIcon();
    
    if (!mounted) return;
    
    final newIcon = await showDialog<String>(
      context: context,
      builder: (context) => DbIconSelectionDialog(
        selectedIcon: currentIcon,
        onIconSelected: (icon) {
        },
        title: '选择应用图标',
      ),
    );
    
    if (newIcon != null) {
      // 更新应用图标
      await localStorageService.setAppIcon(newIcon);
      if (widget.onRefreshSidebar!=null) {
        widget.onRefreshSidebar!();
      }
      setState(() {
        _appIcon = newIcon;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('应用图标修改成功')),
        );
      }
    }
  }

  Widget _buildDatabaseSetting(BuildContext context, AppLocalizations translations, SettingTreeItem treeNode, OPDatabase db) {
    var name = treeNode.name(translations);
    var desc = treeNode.desc(translations);
    var key = treeNode.key;
    if (key==":database_icon")
    {
      return databaseIcon(db);
    } else if (key=='op_import_kdbx') {
      return _buildButtonItem(context, translations, treeNode, onTap: _importKdbxDatabase);
    } else if (key=='op_lock_database') {
      return _buildButtonItem(context, translations, treeNode, onTap: _lockDatabase);
    }else if (key=='op_delete_database') {
      return _buildButtonItem(context, translations, treeNode, onTap: _deleteDatabase);
    } else {
      bool isReadonly = treeNode.key=='UUID' || treeNode.key=='file';
      if (db.isReadonly) isReadonly = true;
      Widget trailing = getDbSetting(db, treeNode.key, isReadonly);

      return ListTile(
        leading: treeNode.icon!=null?Icon(treeNode.icon, color: Colors.blue):null,
        title: Text(name, maxLines:1),
        subtitle: desc.isEmpty
          ? null
          : Text(desc,
            style: const TextStyle(color: Colors.grey),
            maxLines:1
          ),
        trailing: trailing,
        onTap: () {
          if (isReadonly){
            // copy
          }else{
            setCurrentNode(treeNode, true);
          }
        },
      );
    }
  }

  List<Widget> _buildSettingItems(BuildContext context, AppLocalizations translations) {
    final itemListService = ref.read(itemListServiceProvider);
    List<Widget> ret = [];
    List<Widget> widgets = [];
    SettingTreeItem? group;
    if (_currentNode.children!=null) {
      for (var n in _currentNode.children!) {
        var key = n.key;
        if (key.substring(0,1)=='#'){
          // 如果是分组
          if (group!=null){
            ret.add(_buildSettingSection(group.name(translations), widgets));
          }
          widgets.clear();
          group = n;
        }else if (key==':allDatabase'){
          var databases = itemListService.opRoot.allDatabases;
          if (databases.isEmpty){
            widgets.add(const ListTile(
              title: Text(
                '暂无数据库',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis
              ),
            ));
          }else{
            for (var db in databases) {
              widgets.add(_buildDatabase(db));
            }
          }
        }else{
          var w = _inDatabase!=null
            ? _buildDatabaseSetting(context, translations, n, _inDatabase!)
            : _buildAppSettingItem(context, translations, n);
          if (group==null){
            ret.add(w);
          }else{
            widgets.add(w);
          }
        }
      }
      if (group!=null){
        ret.add(_buildSettingSection(group.name(translations), widgets));
      }
      ret.add(SizedBox(height:50));
    }else{
      ret.add(SizedBox(height:10));
      ret.add(_buildSettingValue(context, translations, _currentNode));
      ret.add(SizedBox(height:50));
    }
    return ret;
  }

  Widget getDbSetting(OPDatabase db, String key, bool isReadonly){
    if (db.kdbx==null) {
      return SizedBox.shrink();
    }
    var kdbx = db.kdbx!;
    if (key=='recycleBinEnabled' && !isReadonly){
      return Switch(
        value: kdbx.meta.recycleBinEnabled,
        onChanged: (value) {
          kdbx.meta.recycleBinEnabled = value;
          _onDbSettingChanged();
        },
      );
    }

    String value = '';
    switch (key){
      case 'UUID':
        value = db.dbid;
        break;
      case 'file':
        value = db.dbInfo.filePath;
        break;
      case 'name':
        value = db.name;
        break;
      case 'desc':
        value = kdbx.meta.description??'';
        break;
      case 'historyMaxItems':
        value = (kdbx.meta.historyMaxItems??0).toString();
        break;
      case 'historyMaxSize':
        value = ((kdbx.meta.historyMaxSize??0)/(1024*1024)).floor().toString();
        break;
      case 'recycleBinEnabled':
        value = kdbx.meta.recycleBinEnabled.toString();
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          maxLines:1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
        isReadonly
          ? const Icon(Icons.copy, color: Colors.grey, size: 16)
          : const Icon(Icons.arrow_forward_ios, size: 16),
      ],
    );
  }

  void setDbSetting(String key, String val){
    if (_inDatabase==null) return;
    var db = _inDatabase!;
    if (db.kdbx==null) {
      return;
    }
    var kdbx = db.kdbx!;
    bool isDbChanged = false;
    switch (key){
      case 'name':
        kdbx.root.name = val;
        db.dbInfo.name = val;
        isDbChanged = true;
        break;
      case 'desc':
        kdbx.meta.description = val;
        isDbChanged = true;
        break;
      case 'historyMaxItems':
        var v = int.tryParse(val);
        if (v!=null){
          kdbx.meta.historyMaxItems = v;
          isDbChanged = true;
        }
        break;
      case 'historyMaxSize':
        var v = int.tryParse(val);
        if (v!=null){
          kdbx.meta.historyMaxSize = v*1024*1024;
          isDbChanged = true;
        }
        break;
      case 'recycleBinEnabled':
        var v = bool.tryParse(val);
        if (v!=null){
          kdbx.meta.recycleBinEnabled = v;
          isDbChanged = true;
        }
        break;
    }
    if (isDbChanged){
      final itemListService = ref.read(itemListServiceProvider);
      itemListService.opRoot.onDatabaseChanged(db);
    }
  }

  void _onDbSettingChanged(){
    setState(() {
    });
  }

  Widget databaseIcon(OPDatabase db){
    bool isReadonly = db.isReadonly;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Stack(
          children: [
            InkWell(
              onTap: () {
                if (!isReadonly) showSelectIconDialog(context);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: db.databaseIcon(size:64),
              ),
            ),
            if (!isReadonly) Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showSelectIconDialog(BuildContext context) {
    if (_inDatabase==null) return;
    showDialog(
      context: context,
      builder: (context) => DbIconSelectionDialog(
        selectedIcon: _inDatabase!.getDatabaseIcon(),
        onIconSelected: (icon) {
          final localStorageService = ref.read(localStorageServiceProvider);
          localStorageService.setDatabaseIcon(_inDatabase!, icon);
          setState(() {
          });
        },
        title: '选择应用图标',
      ),
    );
  }

  // // 显示自动锁定时间选择对话框
  // void _showAutoLockTimeDialog() {
  //   final options = [1, 5, 10, 15, 30, 60];
  //   final currentTime = _userDataService.getAutoLockTime();
    
  //   showDialog(
  //     context: context,
  //     builder: (context) => SimpleDialog(
  //       title: const Text('选择自动锁定时间'),
  //       children: options.map((time) => SimpleDialogOption(
  //         onPressed: () {
  //           setState(() {
  //             _userDataService.setAutoLockTime(time);
  //           });
  //           Navigator.pop(context);
  //         },
  //         child: Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 8.0),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Text('$time 分钟'),
  //               if (currentTime == time)
  //                 const Icon(Icons.check, color: Colors.blue)
  //             ],
  //           ),
  //         ),
  //       )).toList(),
  //     ),
  //   );
  // }


  Future<void> _importKdbxDatabase() async {
    if (_inDatabase==null) return;
    if (_inDatabase!.kdbx==null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ImportKdbxDatabasePage(
          targetDatabase: _inDatabase!, // 传入当前数据库作为目标
        ),
      ),
    );
    
    if (result == true) {
      if (mounted) {
        // 导入成功，可以在这里刷新界面或显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据库导入成功')),
        );
      }
    }
  }


  Future<void> _lockDatabase() async {
    // 锁定数据库
    // widget.database.isUnlocked = false;
    // _itemService.notifyListeners();
    
    // if (mounted) {
    //   Navigator.pop(context, true);
    // }

  }

  Future<void> _deleteDatabase() async {
    var db = _inDatabase!;
    _showDeleteDialog(
      icon: Icons.delete_forever,//db.databaseIcon,
      title: '确认删除保险库',
      msg: '此操作将永久删除该保险库及其中的所有数据，此操作无法撤销。',
      targetType: '保险库名称',
      targetName: db.name,
      operateName: "永久删除",
      onConfirm:() {
        final itemListService = ref.read(itemListServiceProvider);
        itemListService.removeDatabase(db, true);
      }
    );
  }

  Future<void> _eraseLocalData(BuildContext context) async {
    _showDeleteDialog(
      icon: Icons.delete_forever,
      title: '确认抹除本地数据',
      msg: '此操作将抹除本地存储的加密数据、主密钥、内部保险库等。此操作无法撤销。',
      targetType: '确认字符串',
      targetName: '抹除所有本地数据',
      operateName: "永久抹除本地数据",
      onConfirm:() async {
        final itemListService = ref.read(itemListServiceProvider);
        await itemListService.clearLocalData();
        final appSettingsService = ref.read(appSettingsServiceProvider);
        await appSettingsService.clearLocalData();
        final localStorageService = ref.read(localStorageServiceProvider);
        await localStorageService.clearLocalData();
        if (mounted){
          AppRouter().navigateTo(context, AppPage.onboarding);
        }
      }
    );
  }

  Future<void> _showDeleteDialog({
    required IconData icon,
    required String title,
    required String msg,
    required String targetType,
    required String targetName,
    required String operateName,
    Function()? onConfirm,
  }) async {
    final TextEditingController confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Stack(
          children: [
            Container(
              width: 400,
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部警告区域
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      // borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        // 保险库图标
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            // color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(icon, size: 40, color: Colors.red),
                        ),
                        const SizedBox(height: 20),
                        // 警告标题
                        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  // 内容区域
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      children: [
                        // 警告信息
                        Text(msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[800], fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '请输入$targetType “$targetName” 以$operateName',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600],fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        
                        // 输入框
                        TextField(
                          controller: confirmController,
                          decoration: InputDecoration(
                            hintText: '输入$targetType',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 删除按钮
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: confirmController,
                          builder: (context, value, child) {
                            bool isValid = value.text == targetName;
                            return ElevatedButton.icon(
                              onPressed: isValid
                                  ? () => Navigator.pop(context, true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_forever),
                              label: Text(
                                operateName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
                label: const Text(
                  '取消',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (onConfirm!=null){
        onConfirm.call();
        // if (mounted) {
        //   Navigator.pop(context, true);
        // }
      }
    }
  }

  void _showSyncBaiduDialog() {
  //   final syncService = ref.read(syncServiceProvider);
  //   final isSyncing = ValueNotifier<bool>(false);
  //   final isLoggedIn = ValueNotifier<bool>(syncService.isBaiduLoggedIn());
  //   final syncStatus = ValueNotifier<String>('');
  //   final autoSync = ValueNotifier<bool>(syncService.isAutoSyncEnabled());

  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('百度网盘同步'),
  //       content: StatefulBuilder(
  //         builder: (context, setState) {
  //           return Container(
  //             width: 400,
  //             constraints: const BoxConstraints(maxWidth: 400),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 // 登录状态
  //                 ValueListenableBuilder<bool>(
  //                   valueListenable: isLoggedIn,
  //                   builder: (context, loggedIn, child) {
  //                     return Card(
  //                       elevation: 2,
  //                       margin: const EdgeInsets.only(bottom: 16),
  //                       child: Padding(
  //                         padding: const EdgeInsets.all(16.0),
  //                         child: Row(
  //                           children: [
  //                             Container(
  //                               width: 40,
  //                               height: 40,
  //                               decoration: BoxDecoration(
  //                                 color: loggedIn ? Colors.green[50] : Colors.grey[100],
  //                                 borderRadius: BorderRadius.circular(20),
  //                               ),
  //                               child: Icon(
  //                                 loggedIn ? Icons.cloud_done : Icons.cloud_off,
  //                                 color: loggedIn ? Colors.green : Colors.grey,
  //                               ),
  //                             ),
  //                             const SizedBox(width: 16),
  //                             Expanded(
  //                               child: Column(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: [
  //                                   Text(
  //                                     loggedIn ? '已连接百度网盘' : '未连接百度网盘',
  //                                     style: TextStyle(
  //                                       fontWeight: FontWeight.bold,
  //                                       color: loggedIn ? Colors.green : Colors.grey[700],
  //                                     ),
  //                                   ),
  //                                   if (loggedIn)
  //                                     Text(
  //                                       syncService.getBaiduUserInfo() ?? '未知用户',
  //                                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
  //                                     ),
  //                                 ],
  //                               ),
  //                             ),
  //                             if (loggedIn)
  //                               TextButton(
  //                                 onPressed: () async {
  //                                   await syncService.logoutBaidu();
  //                                   isLoggedIn.value = false;
  //                                 },
  //                                 child: const Text('退出登录'),
  //                               )
  //                             else
  //                               TextButton(
  //                                 onPressed: () async {
  //                                   final success = await syncService.loginBaidu();
  //                                   isLoggedIn.value = success;
  //                                   if (success) {
  //                                     syncStatus.value = '登录成功';
  //                                   } else {
  //                                     syncStatus.value = '登录失败';
  //                                   }
  //                                 },
  //                                 child: const Text('登录'),
  //                               ),
  //                           ],
  //                         ),
  //                       ),
  //                     );
  //                   },
  //                 ),
                  
  //                 // 同步选项
  //                 ValueListenableBuilder<bool>(
  //                   valueListenable: isLoggedIn,
  //                   builder: (context, loggedIn, child) {
  //                     if (!loggedIn) return const SizedBox.shrink();
                      
  //                     return Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         const Text(
  //                           '同步选项',
  //                           style: TextStyle(
  //                             fontSize: 16,
  //                             fontWeight: FontWeight.bold,
  //                           ),
  //                         ),
  //                         const SizedBox(height: 8),
                          
  //                         // 自动同步开关
  //                         Card(
  //                           elevation: 1,
  //                           child: Padding(
  //                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //                             child: Row(
  //                               children: [
  //                                 const Expanded(
  //                                   child: Column(
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: [
  //                                       Text(
  //                                         '自动同步',
  //                                         style: TextStyle(fontWeight: FontWeight.w500),
  //                                       ),
  //                                       Text(
  //                                         '在数据变更时自动上传到百度网盘',
  //                                         style: TextStyle(fontSize: 12, color: Colors.grey),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                                 ValueListenableBuilder<bool>(
  //                                   valueListenable: autoSync,
  //                                   builder: (context, enabled, _) {
  //                                     return Switch(
  //                                       value: enabled,
  //                                       onChanged: (value) async {
  //                                         await syncService.setAutoSync(value);
  //                                         autoSync.value = value;
  //                                       },
  //                                     );
  //                                   },
  //                                 ),
  //                               ],
  //                             ),
  //                           ),
  //                         ),
                          
  //                         const SizedBox(height: 16),
                          
  //                         // 手动同步按钮
  //                         ValueListenableBuilder<bool>(
  //                           valueListenable: isSyncing,
  //                           builder: (context, syncing, _) {
  //                             return ElevatedButton.icon(
  //                               onPressed: syncing
  //                                   ? null
  //                                   : () async {
  //                                       isSyncing.value = true;
  //                                       syncStatus.value = '正在同步...';
  //                                       try {
  //                                         final result = await syncService.syncWithBaidu();
  //                                         syncStatus.value = result
  //                                             ? '同步成功'
  //                                             : '同步失败';
  //                                       } catch (e) {
  //                                         syncStatus.value = '同步出错: $e';
  //                                       } finally {
  //                                         isSyncing.value = false;
  //                                       }
  //                                     },
  //                               icon: syncing
  //                                   ? Container(
  //                                       width: 24,
  //                                       height: 24,
  //                                       padding: const EdgeInsets.all(2.0),
  //                                       child: const CircularProgressIndicator(
  //                                         strokeWidth: 2,
  //                                       ),
  //                                     )
  //                                   : const Icon(Icons.sync),
  //                               label: Text(syncing ? '同步中...' : '立即同步'),
  //                               style: ElevatedButton.styleFrom(
  //                                 minimumSize: const Size(double.infinity, 48),
  //                               ),
  //                             );
  //                           },
  //                         ),
                          
  //                         const SizedBox(height: 8),
                          
  //                         // 同步状态
  //                         ValueListenableBuilder<String>(
  //                           valueListenable: syncStatus,
  //                           builder: (context, status, _) {
  //                             if (status.isEmpty) return const SizedBox.shrink();
                              
  //                             return Padding(
  //                               padding: const EdgeInsets.symmetric(vertical: 8.0),
  //                               child: Text(
  //                                 status,
  //                                 style: TextStyle(
  //                                   color: status.contains('成功')
  //                                       ? Colors.green
  //                                       : status.contains('失败') || status.contains('出错')
  //                                           ? Colors.red
  //                                           : Colors.blue,
  //                                 ),
  //                               ),
  //                             );
  //                           },
  //                         ),
                          
  //                         const SizedBox(height: 16),
                          
  //                         // 同步路径设置
  //                         const Text(
  //                           '同步设置',
  //                           style: TextStyle(
  //                             fontSize: 16,
  //                             fontWeight: FontWeight.bold,
  //                           ),
  //                         ),
  //                         const SizedBox(height: 8),
                          
  //                         ListTile(
  //                           title: const Text('百度网盘同步路径'),
  //                           subtitle: Text(
  //                             syncService.getBaiduSyncPath() ?? '/apps/openpass/',
  //                             style: TextStyle(fontSize: 12),
  //                           ),
  //                           trailing: const Icon(Icons.edit, size: 16),
  //                           contentPadding: EdgeInsets.zero,
  //                           onTap: () async {
  //                             final controller = TextEditingController(
  //                               text: syncService.getBaiduSyncPath() ?? '/apps/openpass/',
  //                             );
                              
  //                             final newPath = await showDialog<String>(
  //                               context: context,
  //                               builder: (context) => AlertDialog(
  //                                 title: const Text('设置同步路径'),
  //                                 content: TextField(
  //                                   controller: controller,
  //                                   decoration: const InputDecoration(
  //                                     labelText: '百度网盘路径',
  //                                     hintText: '/apps/openpass/',
  //                                     border: OutlineInputBorder(),
  //                                   ),
  //                                 ),
  //                                 actions: [
  //                                   TextButton(
  //                                     onPressed: () => Navigator.pop(context),
  //                                     child: const Text('取消'),
  //                                   ),
  //                                   ElevatedButton(
  //                                     onPressed: () => Navigator.pop(context, controller.text),
  //                                     child: const Text('确定'),
  //                                   ),
  //                                 ],
  //                               ),
  //                             );
                              
  //                             if (newPath != null) {
  //                               await syncService.setBaiduSyncPath(newPath);
  //                               setState(() {});
  //                             }
  //                           },
  //                         ),
  //                       ],
  //                     );
  //                   },
  //                 ),
                  
  //                 // 未登录时的说明
  //                 ValueListenableBuilder<bool>(
  //                   valueListenable: isLoggedIn,
  //                   builder: (context, loggedIn, child) {
  //                     if (loggedIn) return const SizedBox.shrink();
                      
  //                     return const Padding(
  //                       padding: EdgeInsets.symmetric(vertical: 16.0),
  //                       child: Column(
  //                         crossAxisAlignment: CrossAxisAlignment.start,
  //                         children: [
  //                           Text(
  //                             '使用百度网盘同步您的数据',
  //                             style: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                             ),
  //                           ),
  //                           SizedBox(height: 8),
  //                           Text(
  //                             '• 您的数据在上传前会进行加密\n'
  //                             '• 同步可以在多设备间共享您的保险库\n'
  //                             '• 需要百度网盘账号授权',
  //                             style: TextStyle(color: Colors.grey),
  //                           ),
  //                         ],
  //                       ),
  //                     );
  //                   },
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('关闭'),
  //         ),
  //       ],
  //     ),
  //   );
  }
}
