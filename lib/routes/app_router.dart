import 'package:flutter/material.dart';
import '../pages/onboarding/onboarding_page.dart';
import '../pages/login_page.dart';
import '../pages/main_page.dart';

// 定义应用的页面类型
enum AppPage {
  onboarding,
  login,
  main,
}

class AppRouter {
  // 当前页面
  AppPage _currentPage = AppPage.onboarding;

  AppPage get currentPage => _currentPage;
  
  // 初始化路由 - 使用 Riverpod 获取 AppSettingsService
  // 初始化路由
  Future<AppPage> getInitialPage(bool isOnboardingComplete) async {
    try {
      // await Future.delayed(const Duration(seconds: 3));

      if (!isOnboardingComplete) {
        _currentPage = AppPage.onboarding;
        return AppPage.onboarding;
      } else {
        _currentPage = AppPage.login;
        return AppPage.login;
      }
    } catch (e) {
      // 如果出现异常，默认进入引导页
      _currentPage = AppPage.onboarding;
      return AppPage.onboarding;
    }
  }
  
  // 导航到指定页面
  void navigateTo(BuildContext context, AppPage page, {int initialIndex = 0}) {
    _currentPage = page;
    
    // 使用简单的页面替换，而不是复杂的路由
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => buildPage(context, page, initialIndex),
      ),
    );
  }
  
  // 构建页面
  Widget buildPage(BuildContext context, AppPage page, int initialIndex) {
    switch (page) {
      case AppPage.onboarding:
        return const OnboardingPage();
      case AppPage.login:
        return const LoginPage();
      case AppPage.main:
        return MainPage(initialIndex: initialIndex);
    }
  }
  
  // 处理未知路由
  Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('页面未找到'),
        ),
        body: const Center(
          child: Text('请求的页面不存在'),
        ),
      ),
    );
  }
  
  // 路由观察者，用于跟踪导航事件
  RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
}