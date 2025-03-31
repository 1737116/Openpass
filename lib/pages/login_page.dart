import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../routes/app_router.dart';
import '../utils/vault_icons.dart';
import '../providers/providers.dart';
import '../widgets/unlock_animation.dart';
import '../widgets/vault_icon_widget.dart';
import '../services/biometric_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final BiometricService _biometricService = BiometricService();
  bool _useBiometrics = false;
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscureText = true;
  int _unlockState = 0; // 0 默认, 1 解锁中, 2 已解锁
  bool _isLoading = true;  // 加载状态
  bool _showLoginForm = false; // 是否显示登录
  String _userIconPath = VaultIcons.getRandomIcon();
  String _userNickname = "个人";
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey();
  bool _isShaking = false;
  
  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      setState(() {});  // 焦点变化时刷新界面
    });
    _initializeApp();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.removeListener(() {});
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final appSettings = ref.read(appSettingsServiceProvider);
    final iconPath = VaultIcons.checkIcon(appSettings.getAppIcon()??'');
    final nickname = appSettings.getNickname();
    _useBiometrics = appSettings.isUseBiometrics();

    setState(() {
      _userIconPath = iconPath;
      if (nickname.isNotEmpty) {
        _userNickname = nickname;
      }
    });
    
    _afterUserDataLoaded();
  }

  void _afterUserDataLoaded() {
    final localStorageService = ref.read(localStorageServiceProvider);
    if (localStorageService.isPasswordVaild()) {
      // 如果已经有密码，直接解锁
      print('_afterUserDataLoaded');
      _unlockUserData();
    } else {
      // 如果需要密码，显示登录表单
      _showPasswordControl();
    }
  }

  void _showPasswordControl() {
    _biometricService.checkBiometrics().then((_)=>{
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showLoginForm = true;
        }),
        // 如果支持生物识别，自动尝试认证
        if (_biometricService.isEnabled() && _useBiometrics) {
          _authenticateWithBiometrics()
        } else {
          _passwordFocusNode.requestFocus()
        }
      }
    });  // 检查生物识别
  }

  Future<void> _authenticateWithBiometrics() async {
    final localStorageService = ref.read(localStorageServiceProvider);
    final appSettingsService = ref.read(appSettingsServiceProvider);
    
    // 检查是否已经设置了主密码
    if (!_useBiometrics) {
      _showMessage('尚未开启生物识别');
      return;
    }
      
    // 尝试使用生物识别进行认证
    final authenticated = await _biometricService.authenticate(
      reason: '请使用 Windows Hello 进行身份验证'
    );

    if (authenticated) {
      // 认证成功，解锁应用
      String pwd = await appSettingsService.getMasterPwd();
      await localStorageService.setPwdByBio(pwd);
      await _unlockUserData();
    } else {
      _showMessage('生物识别认证失败');
    }
  }

  Future<void> _unlockUserData() async {
    // 设置解锁中状态，显示加载动画
    setState(() {
      _unlockState = 1;
    });

    final localStorageService = ref.read(localStorageServiceProvider);
    final result = await localStorageService.unlockByPassword();

    if (!mounted) return;

    if (result) {
      // 解锁成功，进入主页面
      _moveToMainPage();
    } else {
      // 解锁失败，显示错误信息并重置状态
      _showMessage('密码错误。');
      setState(() {
        _unlockState = 0;
        _isShaking = true;  // 触发晃动效果
      });

      // 晃动效果结束后重置状态
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isShaking = false;
          });
          _passwordFocusNode.requestFocus();  // 重新获取焦点
        }
      });

      _showPasswordControl();
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _onEnterPassword() async {
    final localStorageService = ref.read(localStorageServiceProvider);
    var pwd = _passwordController.text;
    await localStorageService.setupPassword(pwd);
    // print('_onEnterPassword');
    _unlockUserData();
  }

  Future<void> _moveToMainPage() async {
    setState(() {
      _unlockState = 1;
    });

    final itemListService = ref.read(itemListServiceProvider);
    await Future.delayed(Duration.zero);
    await itemListService.openAllDatabase();

    if (mounted) {
      setState(() {
        _unlockState = 2;
      });
      // 使用命名路由导航到主页，让路由系统根据设备类型选择合适的布局
      AppRouter().navigateTo(context, AppPage.main);
      // Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标
              _buildIcon(),
              const SizedBox(height: 24),

              // 昵称
              Text(_userNickname, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),

              // 输入框
              if (_showLoginForm) _buildPasswordInput(),
            ],
          ),
        ),
      ),
    );
  }

  // icon部分
  Widget _buildIcon() {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _unlockState==0
          ? _buildIconLocked()
          : _unlockState==1
            ? _buildIconUnlocking()
            : _buildIconUnlocked()
      ),
    );
  }

  Widget _buildIconLocked(){
    return _isLoading ? const CircularProgressIndicator() : _buildIconRaw();
  }

  Widget _buildIconUnlocking(){
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildIconRaw(),
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconUnlocked(){
    return UnlockAnimation(
      isUnlocking: false,
      unlocked: true,
    );
  }

  Widget _buildIconRaw(){
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[100],
      ),
      padding: const EdgeInsets.all(16),
      child: VaultIconWidget(iconName:_userIconPath),
    );
  }

  Widget _buildPasswordInput() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // const Text(
          //   '请输入密码',
          //   textAlign: TextAlign.center,
          // ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 密码输入框
              Expanded(child: 
                // 密码输入框，使用TweenAnimationBuilder实现晃动效果
                TweenAnimationBuilder<double>(
                  key: _shakeKey,
                  tween: Tween<double>(begin: 0, end: _isShaking ? 1 : 0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticIn,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(sin(value * 10 * pi) * 10, 0),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    enabled: _unlockState==0,
                    decoration: InputDecoration(
                      labelText: '主密码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_passwordFocusNode.hasFocus||true) IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_outlined : Icons.visibility,
                              color: controlColor(),
                            ),
                            onPressed: _unlockState!=0 ? null : () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                            tooltip: _obscureText ? '显示密码' : '隐藏密码',
                          ),
                          // if (_biometricService.isEnabled() && _useBiometrics) ...[
                          //   Container(
                          //     height: 24,
                          //     width: 1,
                          //     color: Colors.grey.withAlpha(75),
                          //     margin: const EdgeInsets.symmetric(vertical: 8),
                          //   ),
                          //   IconButton(
                          //     icon: Icon(
                          //       _biometricService.getBiometricIcon(),
                          //       color: controlColor(),
                          //     ),
                          //     onPressed: _unlockState != 0 ? null : _authenticateWithBiometrics,
                          //     tooltip: _biometricService.getBiometricTooltip(),
                          //   ),
                          // ],
                        ],
                      ),
                      // 在解锁中时改变输入框样式
                      filled: _unlockState!=0,
                      fillColor: _unlockState!=0 ? Colors.grey[100] : null,
                    ),
                    style: TextStyle(
                      color: _unlockState!=0 ? Colors.grey : null,
                    ),
                    obscureText: _obscureText,
                    onSubmitted: _unlockState!=0 ? null : (_) => _onEnterPassword(),
                  ),
                ),
              ),
                
              // 添加生物识别按钮
              if (_biometricService.isEnabled() && _useBiometrics)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    height: 56, // 与输入框高度一致
                    child: OutlinedButton(
                      onPressed: _unlockState != 0 ? null : _authenticateWithBiometrics,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12.0),
                        side: BorderSide(
                          color: controlColor().withAlpha(200),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                        ),
                      ),
                      child: Icon(
                        _biometricService.getBiometricIcon(),
                        color: controlColor(),
                        size: 24,
                      ),
                    )
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),
          
        ],
      ),
    );
  }
  
  Color controlColor(){
    return _unlockState!=0 
      ? Theme.of(context).disabledColor 
      : Theme.of(context).primaryColor;
  }
}