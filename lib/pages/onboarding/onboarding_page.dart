import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../utils/vault_icons.dart';
import '../../utils/password_utils.dart';
import '../../utils/secret_utils.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../../services/theme_service.dart';
import '../../widgets/dbicon_selection_dialog.dart';
import '../../widgets/vault_icon_widget.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController(text: "个人");
  final _formKey = GlobalKey<FormState>();
  OverlayEntry? _overlayEntry;
  
  int _currentPage = 0;
  String _selectedIcon = '';
  String? _generatedMasterKey;
  String? _userUuid; // 用户唯一标识符
  String? _publicKeyString;
  String? _privateKeyString;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isKeyGenerated = false;
  bool _isBackupComplete = false;
  bool _isGeneratingKey = false;
  String _genStepMsg = 'none';
  
  @override
  void initState() {
    super.initState();
    // 初始化时随机选择一个图标
    _selectedIcon = VaultIcons.getRandomIcon();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1) {
      // 验证密码表单
      if (_formKey.currentState!.validate()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // 自动开始生成密钥
        _generateKeyWithAnimation();
      }
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 带动画的密钥生成
  Future<void> _generateKeyWithAnimation() async {
    setState(() {
      _isGeneratingKey = true;
    });
    
    // 模拟生成过程的延迟
    await Future.delayed(const Duration(seconds: 2));
    
    // 生成密钥
    _generatedMasterKey = SecretUtils.generateMasterKey();
    _userUuid = _generateUserUuid();
    _generateUserKeyPair();
    
    setState(() {
      _isGeneratingKey = false;
      _isKeyGenerated = true;
    });
  }

  Future<void> _saveKeyToFile() async {
    try {
      // 打开文件保存对话框
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '保存主密钥',
        fileName: 'openpass_master_key.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      
      if (outputFile == null) {
        // 用户取消了保存操作
        if (mounted) {
          _showCustomToast('保存已取消', isSuccess: false);
        }
        return;
      }
      
      // 创建文件并写入密钥
      final file = File(outputFile);
      await file.writeAsString(_generatedMasterKey ?? '');
      
      // 打开文件保存对话框或分享文件
      setState(() {
        _isBackupComplete = true;
      });
      
      if (mounted) {
        _showCustomToast('密钥已保存到: $outputFile');
      }
    } catch (e) {
      if (mounted) {
        _showCustomToast('保存失败: $e', isSuccess: false);
      }
    }
  }

  // 生成用户 UUID
  String _generateUserUuid() {
    const uuid = Uuid();
    return uuid.v4();
  }
  
  // 生成用户公钥私钥对
  void _generateUserKeyPair() {
    final (publicKey, privateKey) = SecretUtils.generateUserKeyPairStr();
    _publicKeyString = publicKey;
    _privateKeyString = privateKey;
  }
  

  // 保存设置并完成初始化
  Future<void> _completeSetup() async {
    // 显示初始化中的动画
    _genStepMsg = '正在设置个人信息...';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('正在初始化您的密码库...'),
              const SizedBox(height: 10),
              StreamBuilder<String>(
                stream: _getInitializationSteps(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? '准备中...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    try {
      String password = _passwordController.text;
      String nickname = _nicknameController.text;

      // 设置用户数据
      final localStorageService = ref.read(localStorageServiceProvider);
      await localStorageService.setUserData(
        _userUuid ?? '', 
        nickname,
        _selectedIcon,
        _publicKeyString ?? '', 
        _privateKeyString ?? '', 
        _generatedMasterKey ?? ''
      );

      // 设置应用图标和昵称
      final appSettings = ref.read(appSettingsServiceProvider);
      await appSettings.setAppIcon(_selectedIcon);
      await appSettings.setNickname(nickname);
      await appSettings.setMasterKey(_generatedMasterKey ?? '');
      await appSettings.setUserUUID(_userUuid ?? '');

      // 设置密码
      await localStorageService.setupPassword(password);
      await localStorageService.setupKeyAndSalt(_generatedMasterKey??'', _userUuid??'');
      
      // 创建默认保险库
      _genStepMsg = '正在创建默认保险库...';
      await _createDefaultVault(_generatedMasterKey ?? '');
      
      // 加密保存数据
      _genStepMsg = '正在加密数据...';
      await localStorageService.saveUserData();
      
      // 尝试重新载入
      _genStepMsg = '正在完成设置...';
      await localStorageService.loadUserData(clearBefore: true);

      // 清除敏感数据
      _generatedMasterKey = null;

      // 关闭加载对话框
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 导航到主页面
      if (mounted) {
        AppRouter().navigateTo(context, AppPage.login);
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 显示错误信息
      if (mounted) {
        _showCustomToast('初始化失败: $e', isSuccess: false);
      }
    }
  }

  // 创建默认保险库
  Future<void> _createDefaultVault(String masterKey) async {
    // 创建数据库
    final localStorageService = ref.read(localStorageServiceProvider);
    final fileName = await localStorageService.getNewDatabaseFilename();
    final filePath = '#/$fileName';
    final password = SecretUtils.generateDatabasePassword(); 
    final dbName = '个人保险库';
    final dbDesc = '存储您的个人密码和重要信息';
    final iconData = Icons.person; // 或者使用 VaultIcons.vaultIconNames['个人']

    // 创建数据库
    final keepassFileService = ref.read(keepassFileServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    final success = await keepassFileService.createKeePassFile(
      itemListService.opRoot,
      filePath,
      dbName,
      dbDesc,
      iconData,
      password,
    );

    if (itemListService.opRoot.allDatabases.isNotEmpty) {
      var db = itemListService.opRoot.allDatabases[0];
      db.dbInfo.dbIcon = VaultIcons.getRandomIcon();
      if (db.kdbx!=null){
        var kdbx = db.kdbx!;
        var entry = kdbx.createEntry(parent: kdbx.root);
        var meta = kdbx.meta;
        entry.fields['Title'] = KdbxTextField.fromText(
          text: 'OpenPass MasterKey', protected: meta.memoryProtection.title);
        entry.fields['Password'] = KdbxTextField.fromText(
          text: masterKey, protected: meta.memoryProtection.password);
        keepassFileService.onDatabaseChanged(db);
      }
    }

    if (!success) {
      throw Exception('创建数据库失败');
    }
  }

  // 获取初始化步骤的流
  Stream<String> _getInitializationSteps() async* {
    while (true) {
      yield _genStepMsg;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部进度指示器
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            
            // 主要内容区域
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildProfileSetupPage(),
                  _buildKeyGenerationPage(),
                ],
              ),
            ),
            
            // 底部导航按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? TextButton(
                          onPressed: _previousPage,
                          child: const Text('上一步'),
                        )
                      : const SizedBox(width: 80),
                  Text('${_currentPage + 1}/3'),
                  _currentPage < 2
                      ? ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(_currentPage == 1 ? '创建密码' : '下一步'),
                        )
                      : ElevatedButton(
                          onPressed: _completeSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('完成设置'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child:Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              '欢迎使用 OpenPass',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '您的安全密码管理工具',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(children: [Text('我们如何保护您的数据', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  Row(children: [Text(' * 您的数据将由主密码和主密钥共同加密')]),
                  Row(children: [Text(' * 主密码存在您的记忆中, 不会被保存')]),
                  Row(children: [Text(' * 主密钥是随机生成的长字串, 仅保存在设备中')]),
                  Row(children: [Text('    - 可以避免密码过于简单的问题')]),
                  Row(children: [Text('    - 主密钥仅在设备中保存')]),
                  Row(children: [Text(' * 使用 PBKDF2 密码推导函数, 大幅增加暴力破解难度')]),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Row(children: [Text('接下来，我们将引导您完成初始设置，包括：', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  _buildFeatureItem(Icons.password_outlined, '创建主密码'),
                  _buildFeatureItem(Icons.key_outlined, '生成主密钥'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 图标、昵称和密码创建页面
  Widget _buildProfileSetupPage() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // // 标题
            // const Text(
            //   '个人设置',
            //   style: TextStyle(
            //     fontSize: 28,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            // const SizedBox(height: 32),
            
            // 头像和昵称区域
            Center(
              child: Column(
                children: [
                  // 应用图标选择（点击后弹出）
                  GestureDetector(
                    onTap: () => _showIconSelectionDialog(),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                        // border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: VaultIconWidget(iconName:_selectedIcon),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 昵称输入
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      controller: _nicknameController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '输入昵称',
                        border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入昵称';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 密码创建部分
            const Text(
              '创建主密码',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请确保记住此密码，一旦丢失将无法打开您的密码库。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // 密码输入框
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: '输入主密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入主密码';
                }
                if (value.length < 8) {
                  return '密码长度至少为8个字符';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            
            // 确认密码输入框
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                hintText: '再次输入主密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请确认主密码';
                }
                if (value != _passwordController.text) {
                  return '两次输入的密码不一致';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // 密码强度指示器
            if (_passwordController.text.isNotEmpty)
              _buildPasswordStrengthIndicator(_passwordController.text),
            
            const SizedBox(height: 16),
            
            // 简化的密码提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '创建强密码的建议',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• 至少8个字符，包含大小写字母、数字和符号'),
                  const Text('• 避免使用容易猜测的信息'),
                  const Text('• 请确保您能记住这个密码，一旦丢失将无法打开您的密码库。'),
                  const Text('• OpenPass无法帮你恢复密码。'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示图标选择对话框
  // void _showIconSelectionDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('选择应用图标'),
  //       content: SizedBox(
  //         width: 300,
  //         height: 200,
  //         child: GridView.builder(
  //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //             crossAxisCount: 4,
  //             crossAxisSpacing: 10,
  //             mainAxisSpacing: 10,
  //           ),
  //           itemCount: VaultIcons.vaultIconOptions.length,
  //           itemBuilder: (context, index) {
  //             final iconPath = VaultIcons.vaultIconOptions[index];
  //             final isSelected = _selectedIcon == iconPath;
              
  //             return GestureDetector(
  //               onTap: () {
  //                 setState(() {
  //                   _selectedIcon = iconPath;
  //                 });
  //                 Navigator.of(context).pop();
  //               },
  //               child: Container(
  //                 decoration: BoxDecoration(
  //                   color: isSelected ? Colors.blue.withAlpha(25) : null,
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: isSelected ? Colors.blue : Colors.grey[300]!,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(8.0),
  //                   child: VaultIconWidget(iconPath),
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('取消'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // 显示图标选择对话框
  void _showIconSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => DbIconSelectionDialog(
        selectedIcon: _selectedIcon,
        onIconSelected: (icon) {
          setState(() {
            _selectedIcon = icon;
          });
        },
        title: '选择应用图标',
      ),
    );
  }

  // 合并密钥生成和备份页面
  Widget _buildKeyGenerationPage() {
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '生成安全密钥',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '主密钥是计算机生成的随机数据，和密码共同用于加密数据。打开密码库需要他们同时正确，缺失任何一个都导致数据无法打开。',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: _isGeneratingKey
                  ? Column(
                      children: [
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '正在生成安全密钥...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : _isKeyGenerated
                      ? Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    '您的主密钥',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _generatedMasterKey ?? '',
                                    style: TextStyle(
                                      fontFamily: themeExtension?.passwordFontFamily,
                                      fontSize: themeExtension?.passwordFontSize,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _generatedMasterKey ?? ''));
                                    _showCustomToast('密钥已复制到剪贴板');
                                    setState(() {
                                      _isBackupComplete = true;
                                    });
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('复制密钥'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _saveKeyToFile();
                                  },
                                  icon: const Icon(Icons.save),
                                  label: const Text('保存密钥'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (_isBackupComplete)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        '备份完成',
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: _generateKeyWithAnimation,
                          icon: const Icon(Icons.key),
                          label: const Text('生成主密钥'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 32),
            const Text(
              '重要提示：',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text('• 主密钥和密码共同用于加密数据，丢失任何一个都会导致无法访问您的数据。'),
            const Text('• 密码由您的大脑记忆，主密钥则保存在本地设备上。'),
            const Text('• 请务必保存您的主密钥，避免设备丢失造成的数据丢失。'),
            const Text('• 建议将主密钥和密码写在纸上，保存到保险箱中。'),
            
          ],
        ),
      ),
    );
  }


  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    final strength = PasswordUtils.calculatePasswordStrength(password);
    Color color;
    String label;
    
    if (strength < 0.3) {
      color = Colors.red;
      label = '弱';
    } else if (strength < 0.6) {
      color = Colors.orange;
      label = '中';
    } else {
      color = Colors.green;
      label = '强';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('密码强度:'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

// 添加一个方法来显示自定义提示
  void _showCustomToast(String message, {bool isSuccess = true}) {
    // 移除之前的提示（如果有）
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        width: MediaQuery.of(context).size.width,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    
    // 2秒后自动移除提示
    Future.delayed(const Duration(seconds: 2), () {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    });
  }
}
