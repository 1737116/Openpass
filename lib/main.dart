import 'dart:io';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'i18n/delegate.dart';
import 'providers/providers.dart';
import 'pages/onboarding/loading_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置应用只支持竖屏模式
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });

  // 初始化服务
  final container = ProviderContainer();

  // 预先加载用户设置
  final appSettingsService = container.read(appSettingsServiceProvider);
  final themeService = container.read(themeServiceProvider);
  final layoutService = container.read(layoutServiceProvider.notifier);
  final localStorageService = container.read(localStorageServiceProvider);

  // 等待主题和布局设置加载完成
  await localStorageService.onAppInit();
  await appSettingsService.loadBasicSettings();
  themeService.onAppInit();
  layoutService.onAppInit();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),  // 调整默认窗口大小更适合PC布局
      center: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 设置状态栏颜色
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // 监听初始页面
    final initialPageAsync = ref.watch(initialPageProvider);
    return initialPageAsync.when(
      data: (initialPage) {
        final appRouter = ref.watch(appRouterProvider);
        final themeService = ref.watch(themeServiceProvider);
        final themeMode = themeService.themeMode;
        
        return MaterialApp(
          title: 'OpenPass',
          theme: themeService.getThemeData(context, isDark: false),
          darkTheme: themeService.getThemeData(context, isDark: true),
          themeMode: themeMode,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh'),
            Locale('en'),
          ],
          home: appRouter.buildPage(context, initialPage, 0),
          onUnknownRoute: appRouter.onUnknownRoute,
          navigatorObservers: [appRouter.routeObserver],
        );
      },
      loading: () => const LoadingPage(),
      error: (error, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('初始化失败: $error'),
          ),
        ),
      ),
    );
  }
}
