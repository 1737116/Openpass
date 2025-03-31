import 'dart:ui';
import 'package:flutter/material.dart';
import 'local_storage_service.dart';
import 'app_settings_service.dart';

class ThemeService extends ChangeNotifier {
  final AppSettingsService _appSettingsService;
  LocalStorageService? _localStorageService;
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode {
    if (_themeMode==ThemeMode.system){
      return false;
    }
    return _themeMode==ThemeMode.dark;
  }

  ThemeService(
    AppSettingsService appSettingsService,
    )
    : _appSettingsService = appSettingsService
    , super();

  void onAppInit() {
    _themeMode = _appSettingsService.savedThemeMode;
  }

  void onAfterLocalStorageInit(LocalStorageService localStorageService) {
    _localStorageService = localStorageService;
  }

  // 切换主题
  Future<void> toggleTheme() async {
    if(_localStorageService!=null){
      int mode = _localStorageService!.getSettingInt('theme_mode');
      await _localStorageService!.setSettingInt('theme_mode', mode==1? 2 : 1);
    }
  }

  void onThemeChanged() {
    int mode = _localStorageService!.getSettingInt('theme_mode');
    _themeMode = mode==1? ThemeMode.light : mode==2? ThemeMode.dark : ThemeMode.system;
    notifyListeners();
  }
  
  // 获取主题数据
  ThemeData getThemeData(BuildContext context, {bool isDark = false}) {
    final baseTheme = isDark ? ThemeData.dark(useMaterial3:false) : ThemeData.light(useMaterial3:false);

    return baseTheme.copyWith(
      // 设置默认字体
      // fontFamily: 'PingFang SC',
      
      // 设置文本主题
      textTheme: baseTheme.textTheme.apply(
        fontFamily: 'PingFang SC',
        bodyColor: isDark ? Colors.white : Colors.black87,
        displayColor: isDark ? Colors.white : Colors.black,
      ),
      
      // 设置主要文本样式
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: 'PingFang SC',
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),

      scaffoldBackgroundColor: isDark? const Color(0xFF121212) : Colors.white,
      cardColor: isDark? const Color(0xFF1F1F1F) : Colors.white,
      dividerColor: isDark? Colors.grey[800] : Colors.grey[300],
      
      extensions: [
        AppThemeExtension(
          // 侧边栏背景色
          sidebarBackgroundColor: isDark 
              ? const Color(0xFF1E1E1E) 
              : const Color(0xFFF5F5F7),
          // 侧边栏选中项背景色
          sidebarSelectedItemColor: isDark 
              ? const Color(0xFF2C2C2E) 
              : const Color(0xFFDCDCDC),
          // 侧边栏文本颜色
          sidebarTextColor: isDark 
              ? Colors.white70 
              : Colors.black87,
          // 侧边栏选中文本颜色
          sidebarSelectedTextColor: isDark 
              ? Colors.white 
              : Colors.black,
          // 侧边栏图标颜色
          sidebarIconColor: isDark 
              ? Colors.white70 
              : Colors.black54,
          // 侧边栏选中图标颜色
          sidebarSelectedIconColor: isDark 
              ? Colors.white 
              : baseTheme.colorScheme.primary,
          // 侧边栏分组标题颜色
          sidebarGroupTitleColor: isDark 
              ? Colors.white60 
              : Colors.black54,
              // 密码显示字体
          passwordFontFamily: 'JetBrains Mono',
          // 密码显示字体大小
          passwordFontSize: 13.0,
          // Colors.blue[50],
          tagBackgroundColor: isDark ? Colors.blue[900]! : Colors.blue[50]!,
        ),
      ],
    );
  }
}

// 创建主题扩展类
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color sidebarBackgroundColor;
  final Color sidebarSelectedItemColor;
  final Color sidebarTextColor;
  final Color sidebarSelectedTextColor;
  final Color sidebarIconColor;
  final Color sidebarSelectedIconColor;
  final Color sidebarGroupTitleColor;
  final Color tagBackgroundColor;
  final String passwordFontFamily;
  final double passwordFontSize;

  AppThemeExtension({
    required this.sidebarBackgroundColor,
    required this.sidebarSelectedItemColor,
    required this.sidebarTextColor,
    required this.sidebarSelectedTextColor,
    required this.sidebarIconColor,
    required this.sidebarSelectedIconColor,
    required this.sidebarGroupTitleColor,
    required this.tagBackgroundColor,
    
    this.passwordFontFamily = 'JetBrains Mono',
    this.passwordFontSize = 13.0,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? sidebarBackgroundColor,
    Color? sidebarSelectedItemColor,
    Color? sidebarTextColor,
    Color? sidebarSelectedTextColor,
    Color? sidebarIconColor,
    Color? sidebarSelectedIconColor,
    Color? sidebarGroupTitleColor,
    Color? tagBackgroundColor,
    String? passwordFontFamily,
    double? passwordFontSize,
  }) {
    return AppThemeExtension(
      sidebarBackgroundColor: sidebarBackgroundColor ?? this.sidebarBackgroundColor,
      sidebarSelectedItemColor: sidebarSelectedItemColor ?? this.sidebarSelectedItemColor,
      sidebarTextColor: sidebarTextColor ?? this.sidebarTextColor,
      sidebarSelectedTextColor: sidebarSelectedTextColor ?? this.sidebarSelectedTextColor,
      sidebarIconColor: sidebarIconColor ?? this.sidebarIconColor,
      sidebarSelectedIconColor: sidebarSelectedIconColor ?? this.sidebarSelectedIconColor,
      sidebarGroupTitleColor: sidebarGroupTitleColor ?? this.sidebarGroupTitleColor,
      tagBackgroundColor: tagBackgroundColor?? this.tagBackgroundColor,
      passwordFontFamily: passwordFontFamily ?? this.passwordFontFamily,
      passwordFontSize: passwordFontSize ?? this.passwordFontSize,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other, 
    double t
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }
    
    return AppThemeExtension(
      sidebarBackgroundColor: Color.lerp(sidebarBackgroundColor, other.sidebarBackgroundColor, t)!,
      sidebarSelectedItemColor: Color.lerp(sidebarSelectedItemColor, other.sidebarSelectedItemColor, t)!,
      sidebarTextColor: Color.lerp(sidebarTextColor, other.sidebarTextColor, t)!,
      sidebarSelectedTextColor: Color.lerp(sidebarSelectedTextColor, other.sidebarSelectedTextColor, t)!,
      sidebarIconColor: Color.lerp(sidebarIconColor, other.sidebarIconColor, t)!,
      sidebarSelectedIconColor: Color.lerp(sidebarSelectedIconColor, other.sidebarSelectedIconColor, t)!,
      sidebarGroupTitleColor: Color.lerp(sidebarGroupTitleColor, other.sidebarGroupTitleColor, t)!,
      tagBackgroundColor: Color.lerp(tagBackgroundColor, other.tagBackgroundColor, t)!,
      passwordFontFamily: t < 0.5 ? passwordFontFamily : other.passwordFontFamily,
      passwordFontSize: lerpDouble(passwordFontSize, other.passwordFontSize, t)!,
    );
  }
}