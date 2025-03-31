import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/password_utils.dart';
import '../utils/secret_utils.dart';
import '../services/theme_service.dart';
import '../services/local_storage_service.dart';

class PasswordGeneratorDialog extends ConsumerStatefulWidget {
  final bool isDialog;
  final String useButtonName;

  const PasswordGeneratorDialog({
    super.key,
    required this.isDialog,
    this.useButtonName = '使用',
  });

  static Future<String?> show(BuildContext context) {
    final layoutService = ProviderScope.containerOf(context).read(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;

    if (isMobileLayout) {
      return showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => PasswordGeneratorDialog(isDialog:false),
        ),
      );
    }else{
      // 桌面布局使用 Dialog
      return showDialog<String?>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            height: 400,
            padding: const EdgeInsets.all(16),
            child: PasswordGeneratorDialog(isDialog:true),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends ConsumerState<PasswordGeneratorDialog> {
  final String _configKey = 'gen_password';
  LocalStorageService? _localStorageService;
  bool _isChanged = false;
  String generatedPassword = '';
  int passwordLength = 12;
  int pinLength = 6;
  bool includeNumbers = true;
  bool includeSymbols = true;
  bool isRandomPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _saveConfig();
    super.dispose();
  }

  void _loadConfig(String config) {
    try {
      var cfg = jsonDecode(config);
      if (cfg is Map<String,dynamic>){
        passwordLength = getJsonInt(cfg, 'passwordLength', 12);
        pinLength = getJsonInt(cfg, 'pinLength', 6);
        includeNumbers = getJsonBool(cfg, 'includeNumbers', true);
        includeSymbols = getJsonBool(cfg, 'includeSymbols', true);
        isRandomPassword = getJsonBool(cfg, 'isRandomPassword', true);
      }
    } catch (e) {
      // 异常使用默认值
    }
  }
  int getJsonInt(Map<String, dynamic> cfg, String key, int defVallue){
    var val = cfg[key];
    if (val is int){
      return val;
    }
    return defVallue;
  }
  bool getJsonBool(Map<String, dynamic> cfg, String key, bool defVallue){
    var val = cfg[key];
    if (val is bool){
      return val;
    }
    return defVallue;
  }

  Future<void> _saveConfig() async {
    if (_isChanged && _localStorageService!=null) {
      final config = {
        'passwordLength': passwordLength,
        'pinLength': pinLength,
        'includeNumbers': includeNumbers,
        'includeSymbols': includeSymbols,
        'isRandomPassword': isRandomPassword,
      };
      _localStorageService!.setSettingStr(_configKey, jsonEncode(config));
    }
  }

  // 修改现有的 setState 调用处
  void _updateSettings(VoidCallback update) {
    setState(() {
      update();
      _generatePassword();
    });
    _isChanged = true;
  }

  void _generatePassword() {
    setState(() {
      if (isRandomPassword) {
        generatedPassword = SecretUtils.generatePassword(passwordLength, includeNumbers, includeSymbols);
      } else {
        generatedPassword = SecretUtils.generatePin(pinLength);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localStorageService==null){
      _localStorageService = ref.read(localStorageServiceProvider);
      if (_localStorageService!=null){
        final cfg = _localStorageService!.getSettingStr(_configKey);
        if (cfg.isNotEmpty){
          _loadConfig(cfg);
        }
      }
      _generatePassword();
    }
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    return Container(
      // title: const Text('生成密码'),
      decoration: const BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动区域
          if (!widget.isDialog) Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // 顶部操作按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('取消'),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generatePassword,
                  label: const Text('随机'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, generatedPassword);
                  },
                  child: Text(widget.useButtonName),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 密码预览
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: themeExtension?.passwordFontFamily,
                    fontSize: themeExtension?.passwordFontSize,
                    letterSpacing: 1.0,
                    // height: 1.5,
                  ),
                  children: PasswordUtils.colorizePassword(generatedPassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 密码强度显示
          LinearProgressIndicator(
            value: PasswordUtils.calculatePasswordStrength(generatedPassword),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              PasswordUtils.getStrengthColor2(generatedPassword),
            ),
          ),
          const SizedBox(height: 16),

          // 选项
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('随机密码'),
                  value: true,
                  groupValue: isRandomPassword,
                  onChanged: (value) {
                    _updateSettings(() {
                        isRandomPassword = value!;
                      });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('数字密码'),
                  value: false,
                  groupValue: isRandomPassword,
                  onChanged: (value) {
                    _updateSettings(() {
                        isRandomPassword = value!;
                      });
                  },
                ),
              ),
            ],
          ),
          if (isRandomPassword) ...[
            ListTile(
              title: Text('随机密码长度: $passwordLength'),
              subtitle: Slider(
                value: passwordLength.toDouble(),
                min: 8,
                max: 50,
                divisions: 42,
                label: passwordLength.toString(),
                onChanged: (value) {
                  _updateSettings(() {
                        passwordLength = value.round();
                      });
                },
              ),
            ),
            CheckboxListTile(
              title: const Text('包含数字'),
              value: includeNumbers,
              onChanged: (value) {
                _updateSettings(() {
                    includeNumbers = value!;
                  });
              },
            ),
            CheckboxListTile(
              title: const Text('包含符号'),
              value: includeSymbols,
              onChanged: (value) {
                _updateSettings(() {
                    includeSymbols = value!;
                  });
              },
            ),
          ] else ...[
            ListTile(
              title: Text('数字密码长度: $pinLength'),
              subtitle: Slider(
                value: pinLength.toDouble(),
                min: 3,
                max: 12,
                divisions: 42,
                label: pinLength.toString(),
                onChanged: (value) {
                  _updateSettings(() {
                    pinLength = value.round();
                  });
                },
              ),
            ),
          ]
        ],
      ),
    );
  }

}
