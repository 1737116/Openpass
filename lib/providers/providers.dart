import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/theme_service.dart';
import '../services/item_list_service.dart';
import '../services/item_detail_service.dart';
import '../services/app_settings_service.dart';
import '../services/layout_service.dart';
import '../services/local_storage_service.dart';
import '../services/keepass_file_service.dart';
import '../services/icon_service.dart';
import '../routes/app_router.dart';

// 路由服务提供者
final appRouterProvider = Provider<AppRouter>((ref) {
  return AppRouter();
});

// 设置服务提供者
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

// 主题服务提供者
final themeServiceProvider = ChangeNotifierProvider<ThemeService>((ref) {
  final appSettingsService = ref.read(appSettingsServiceProvider);
  return ThemeService(appSettingsService);
});

// 布局服务提供者
final layoutServiceProvider = ChangeNotifierProvider<LayoutService>((ref) {
  final appSettingsService = ref.read(appSettingsServiceProvider);
  return LayoutService(appSettingsService);
});

// 初始页面提供者
final initialPageProvider = FutureProvider<AppPage>((ref) async {
  final localStorageService = ref.read(localStorageServiceProvider);
  bool isOnboardingComplete = await localStorageService.loadUserData();
  final appRouter = ref.watch(appRouterProvider);
  return await appRouter.getInitialPage(isOnboardingComplete);
});

// 本地存储服务提供者
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final appSettingsService = ref.read(appSettingsServiceProvider);
  final themeService = ref.read(themeServiceProvider);
  final layoutService = ref.read(layoutServiceProvider);
  return LocalStorageService(appSettingsService, themeService, layoutService);
});

// 导入 KeePass 服务提供者
final keepassFileServiceProvider = Provider<KeePassFileService>((ref) {
  final localStorageService = ref.read(localStorageServiceProvider);
  return KeePassFileService(
    localStorageService: localStorageService,
  );
});

// 项目服务提供者
final itemListServiceProvider = ChangeNotifierProvider<ItemListService>((ref) {
  final localStorageService = ref.read(localStorageServiceProvider);
  final keepassFileService = ref.watch(keepassFileServiceProvider);
  return ItemListService(
    localStorageService: localStorageService,
    keepassImporter: keepassFileService,
  );
});

// 本地存储服务提供者
final itemDetailServiceProvider = ChangeNotifierProvider<ItemDetailService>((ref) {
  return ItemDetailService();
});

// 图标服务
final iconServiceProvider = Provider<IconService>((ref) {
  final localStorageService = ref.read(localStorageServiceProvider);
  return IconService(localStorageService);
});
