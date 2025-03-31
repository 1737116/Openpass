import 'package:flutter/material.dart';
import '../pages/base_page.dart';
import '../pages/home_page.dart';
import '../pages/root_page.dart';
import '../pages/setting_page.dart';
import '../pages/list_page.dart';
import '../widgets/common_navigation_bar.dart';

class MobileLayout extends StatefulWidget {
  final int initialIndex;
  
  const MobileLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MobileLayout> createState() => MobileLayoutState();
}

class MobileLayoutState extends State<MobileLayout> {
  late int _currentIndex;
  final List<GlobalKey<BasePageState>> _pageKeys = [
    GlobalKey<BasePageState>(),
    GlobalKey<BasePageState>(),
    GlobalKey<BasePageState>(),
    GlobalKey<BasePageState>(),
  ];
  final List<BasePage> _pages = [];
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // 为每个页面分配一个 GlobalKey，以便获取其 State
    _pages.addAll([
      HomePage(key: _pageKeys[0], onSwitchPage: _onSwitchPage),
      RootPage(key: _pageKeys[1], onSwitchPage: _onSwitchPage),
      SettingPage(key: _pageKeys[2], onSwitchPage: _onSwitchPage),
      ListPage(key: _pageKeys[3], onSwitchPage: _onSwitchPage),
    ]);
  }

  // 获取当前页面的 State
  BasePageState? get _currentPageState {
    return _pageKeys[_currentIndex].currentState;
  }
  
  @override
  Widget build(BuildContext context) {
    BasePageState? basePageState = _currentPageState;
    return Scaffold(
      appBar: AppBar(
        leading: (basePageState?.showBackButton()??false) ? IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          // splashRadius: 20, // 减小水波纹半径
          // splashColor: Colors.transparent, // 设置水波纹为透明
          // hoverColor: Colors.transparent, // 设置悬停颜色为透明
          // highlightColor: Colors.transparent, // 设置高亮颜色为透明
          onPressed: _onClickBackButton,
        ) : null,
        title: basePageState?.buildTitle() ?? const Text('OpenPass'),
        actions: basePageState?.buildActions() ?? [],
        bottom: basePageState?.buildAppBarBottom(),
        elevation: 5,//_scrollController.hasClients && _scrollController.offset > 0 ? 4 : 0,
        shadowColor: Colors.black.withAlpha(25),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CommonNavigationBar(
        currentIndex: _currentIndex<3?_currentIndex:1,
        onTap: _onSwitchPage,
      ),
    );
  }

  // 如果传入值非 null，就是切换page，否则是刷新标题
  void _onSwitchPage(int? index){
    setState(() {
      if (index!=null){
        _currentIndex = index;
      }
    });
  }

  void _onClickBackButton(){
    _currentPageState?.onBackPressed();
  }
}
