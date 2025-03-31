import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../routes/app_router.dart';
import '../widgets/add_entry_button.dart';
import '../widgets/theme_switch.dart';
import '../widgets/draggable_divider.dart';
import '../widgets/layout_switch.dart';
import '../widgets/common_search_bar.dart';
import '../pages/sidebar_page.dart';
import '../pages/list_page.dart';
import '../pages/detail_page.dart';
import '../pages/detail_edit_page.dart';
import '../pages/setting_page.dart';
import '../services/theme_service.dart';

class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout> {
  double _leftColumnWidth = 220;
  double _middleColumnWidth = 300;
  bool _showSetting = false;
  final GlobalKey<SidebarPageState> _sidebarKey = GlobalKey<SidebarPageState>();

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final themeExtension = themeData.extension<AppThemeExtension>();

    final itemDetailService = ref.watch(itemDetailServiceProvider);
    final selectedItem = itemDetailService.selectedEntry;
    final editingParent = itemDetailService.editingParent;
    final editingEntry = itemDetailService.editingEntry;

    return Scaffold(
      appBar: AppBar(
        leading: SizedBox.shrink(),
        leadingWidth: 10,
        title: const Text('OpenPass'),
        centerTitle: false,
        actions: [
          AddEntryButton(onEntryAdded: () {
            _refreshView();
          }),
          const ThemeSwitch(),
          const LayoutSwitch(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withAlpha(40),
            height: 1.0,
          ),
        ),
        flexibleSpace: Align(
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.only(top: 8),
            child: const CommonSearchBar(),
          ),
        ),
      ),
      body: Row(
        children: [
          // 第一列：菜单导航
          SizedBox(
            width: _leftColumnWidth,
            child: SidebarPage(
              key: _sidebarKey,
              onItemListSelected: (){
                _setSettingState(false);
              },
              onClickMenu: (String menuId){
                if (menuId=='setting') {
                  _setSettingState(!_showSetting);
                }else if (menuId=='lock') {
                  var localStorageService = ref.read(localStorageServiceProvider);
                  localStorageService.lock();
                  AppRouter().navigateTo(context, AppPage.login);
                }
              },
            ),
          ),
          
          // 可拖动的分隔线
          DraggableDivider(
            width: 8,
            color: themeData.dividerColor.withAlpha(40),
            hoverColor: themeData.primaryColor,
            leftBackgroundColor: themeExtension?.sidebarBackgroundColor, // 侧边栏背景色
            rightBackgroundColor: Colors.white, // 内容区域背景色
            onDragUpdate: (delta) {
              setState(() {
                // 限制最小宽度
                _leftColumnWidth = (_leftColumnWidth + delta).clamp(180.0, 350.0);
              });
            },
          ),
          
          // 第二列：列表 或 设置
          if (!_showSetting) SizedBox(
              width: _middleColumnWidth,
              child: ListPage(),
            )
          else
            Expanded(
              child: SettingPage(
                onSwitchPage: (pageIdx) {
                  if (pageIdx!=null) {
                    _setSettingState(false);
                  }
                },
                onRefreshSidebar:(){
                  _refreshView();
                }
              ),
            ),
          
          // 可拖动的分隔线
          if (!_showSetting) DraggableDivider(
            width: 8,
            color: themeData.dividerColor.withAlpha(40),
            hoverColor: themeData.primaryColor,
            onDragUpdate: (delta) {
              setState(() {
                // 限制最小宽度
                _middleColumnWidth = (_middleColumnWidth + delta).clamp(250.0, 450.0);
              });
            },
          ),
          
          // 第三列：详情
          if (!_showSetting) Expanded(
            child: (editingParent!=null && editingEntry!=null)
              ? DetailEditPage(
                onChanged: (isSave) {
                  _refreshView();
                },
              )
              : selectedItem!=null
                ? DetailPage(
                  onChanged: (_) {
                    _refreshView();
                  },
                  onDeleted: (_) {
                    itemDetailService.setSelectedEntry(null, false);
                    _refreshView();
                  },
                )
                : const Center(
                  child:Text("请选择一个项目查看详情")
                ),
          ),
        ],
      ),
    );
  }
  void _refreshView(){
    if (mounted) {
      setState(() {});

      // 刷新侧边栏
      if (_sidebarKey.currentState != null) {
        _sidebarKey.currentState!.refresh();
      }
    }
  }
  void _setSettingState(bool v){
    if (mounted) {
      setState(() {
        _showSetting = v;
      });
    }
  }
}