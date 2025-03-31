import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'app_settings_service.dart';
import 'local_storage_service.dart';

class LayoutService extends ChangeNotifier {
  final AppSettingsService _appSettingsService;
  LocalStorageService? _localStorageService;
  bool _sysIsMobileLayout = true;
  int _layoutMode = 0;

  int get layoutMode => _layoutMode;

  // 初始状态为移动布局
  LayoutService(
    AppSettingsService appSettingsService,
    )
    : _appSettingsService=appSettingsService
    , super();
  
  bool get isMobileLayout => _layoutMode==0? _sysIsMobileLayout: _layoutMode==1;
  
  // 预设系统布局模式（基于设备类型）
  void onAppInit() {
    _detectDeviceType();
    _layoutMode = _appSettingsService.savedLayout;
  }

  Future<void> _detectDeviceType() async {
    // 如果是Web或桌面平台，直接设置为非移动布局
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _sysIsMobileLayout = false;
      notifyListeners();
      return;
    }

    // 使用MediaQuery获取屏幕信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = WidgetsBinding.instance.rootElement;
      if (context != null) {
        final mediaQuery = MediaQuery.of(context);
        final size = mediaQuery.size;
        final devicePixelRatio = mediaQuery.devicePixelRatio;
        
        // 计算物理尺寸（英寸）
        final physicalWidth = size.width * devicePixelRatio;
        final physicalHeight = size.height * devicePixelRatio;
        final diagonalInches = 
            (physicalWidth * physicalWidth + physicalHeight * physicalHeight) / 
            (160 * 160 * devicePixelRatio * devicePixelRatio);
        
        // 对角线尺寸大于7英寸通常被视为平板
        final isTablet = diagonalInches > 7.0;
        
        // 使用device_info_plus作为辅助判断
        _getDeviceTypeInfo(isTablet);
      } else {
        // 如果无法获取context，使用备用方法
        _getDeviceTypeInfo(false);
      }
    });
  }

  Future<void> _getDeviceTypeInfo(bool initialIsTablet) async {
    final deviceInfo = DeviceInfoPlugin();
    bool isTablet = initialIsTablet;
    
    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iOS设备类型判断
        // 使用utsname.machine获取设备型号，更可靠
        final machine = iosInfo.utsname.machine;
        // iPad型号通常以iPad开头
        if (machine.startsWith('iPad')) {
          isTablet = true;
        } else if (machine.startsWith('iPhone') || machine.startsWith('iPod')) {
          isTablet = false;
        }
        // 如果是模拟器，使用model判断
        if (iosInfo.isPhysicalDevice == false) {
          isTablet = iosInfo.model.toLowerCase().contains('ipad');
        }
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        
        // 结合多种方法判断Android设备类型
        // 1. 使用屏幕尺寸和密度
        final screenWidthDp = androidInfo.displayMetrics.widthInches;
        final screenHeightDp = androidInfo.displayMetrics.heightInches;
        final smallestWidthDp = screenWidthDp < screenHeightDp ? screenWidthDp : screenHeightDp;
        
        // 最小宽度大于600dp通常被视为平板
        if (smallestWidthDp >= 600) {
          isTablet = true;
        }
        
        // 2. 检查系统特性
        if (androidInfo.systemFeatures.contains('android.hardware.type.pc')) {
          isTablet = true;
        }
      }
    } catch (e) {
      debugPrint('获取设备信息出错: $e');
      // 出错时保持初始判断结果
    }
    
    _sysIsMobileLayout = !isTablet;
    notifyListeners();
  }

  void onAfterLocalStorageInit(LocalStorageService localStorageService) {
    _localStorageService = localStorageService;
  }

  // 切换布局
  Future<void> toggleLayout() async {
    if (_localStorageService!=null){
      int mode = _localStorageService!.getSettingInt('layout_mode');
      await _localStorageService!.setSettingInt('layout_mode', mode==1? 2 : 1);
    }
  }
  
  void onLayoutChanged(){
    _layoutMode = _localStorageService!.getSettingInt('layout_mode');
    notifyListeners();
  }
}