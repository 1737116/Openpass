import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class BasePage extends ConsumerStatefulWidget {
  final Function(int?)? onSwitchPage;

  const BasePage({
    super.key,
    this.onSwitchPage
  });
  
  @override
  BasePageState createState();
}

abstract class BasePageState<T extends BasePage> extends ConsumerState<T> {
  // 获取页面标题
  Widget buildTitle();
  
  // 获取操作按钮
  List<Widget> buildActions();
  
  // 获取底部栏（可选）
  PreferredSizeWidget? buildAppBarBottom() => null;
  
  // 是否显示返回按钮
  bool showBackButton() => false;
  
  // 处理返回按钮点击事件
  void onBackPressed() {}
  
  // 构建页面内容
  Widget buildBody(BuildContext context);
  
  @override
  Widget build(BuildContext context) {
    return buildBody(context);
  }
}