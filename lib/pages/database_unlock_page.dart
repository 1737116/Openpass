import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../widgets/key_import_dialog.dart';

class UnlockDatabasePage extends ConsumerStatefulWidget {
  final OPDatabase database;

  const UnlockDatabasePage({
    super.key,
    required this.database,
  });

  @override
  ConsumerState<UnlockDatabasePage> createState() => _UnlockDatabasePageState();
}

class _UnlockDatabasePageState extends ConsumerState<UnlockDatabasePage> {
  final TextEditingController _passwordController = TextEditingController();
  String? _fileID;
  String? _keyData;
  bool _isUnlocking = false;
  String? _errorMessage;
  bool _obscureText = true;
  bool _savePassword = false;

  @override
  void initState() {
    super.initState();
    final localStorageService = ref.read(localStorageServiceProvider);
    _savePassword = localStorageService.getSettingBool("autoUnlock");
    // 从最近文件列表中获取密钥数据
    for(var dbInfo in localStorageService.databaseItems) {
      if (dbInfo == widget.database.dbInfo) {
        _fileID = dbInfo.id;
        _keyData = dbInfo.keyData;
        break;
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _showKeyImportDialog() async {
    String? result = await showDialog<String>(
      context: context,
      builder: (context) => KeyImportDialog(
        initialValue: _keyData,
      ),
    );

    if (result != null) {
      setState(() {
        _keyData = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _unlock() async {
    if (_passwordController.text.isEmpty) {
      _showError('请输入密码');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isUnlocking = true;
    });

    try {
      final itemListService = ref.read(itemListServiceProvider);
      final localStorageService = ref.read(localStorageServiceProvider);

      final result = await itemListService.unlockDatabase(
        widget.database,
        _passwordController.text,
        _keyData,
        _savePassword,
      );

      if (!mounted) return;

      if (result) {
        // 更新密钥数据
        if (_fileID!=null && _keyData != null) {
          await localStorageService.updateDatabaseKeyData(_fileID!, _keyData);
        }
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _showError('密码错误');
      }
    } catch (e) {
      String es = e.toString();
      String errorMsg = '解锁失败';
      if (es.contains('InvalidPassword') || es.contains('InvalidCredentials')) {
        errorMsg = '密码错误';
      } else if (es.contains('FileNotFound')) {
        errorMsg = '文件不存在或无法访问';
      } else if (es.contains('InvalidKeyFile')) {
        errorMsg = '密钥文件无效';
      } else if (es.contains('CorruptedFile')) {
        errorMsg = '文件已损坏或格式不正确';
      }
      _showError(errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('解锁'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 数据库图标
                    widget.database.databaseIcon(size:64),
                    const SizedBox(height: 24),

                    // 文件名和密钥按钮
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.database.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _keyData != null ? Icons.key : Icons.key_outlined,
                            color: _keyData != null ? Colors.blue : null,
                          ),
                          onPressed: _showKeyImportDialog,
                          tooltip: '导入密钥文件',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 完整路径
                    Text(
                      widget.database.dbInfo.filePath,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // 密码输入框
                    StatefulBuilder(
                      builder: (context, setState) {
                        return TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: '密码',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureText,
                          onSubmitted: (_) => _unlock(),
                          autofocus: true,
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // 保存密码开关
                    SwitchListTile(
                      title: const Text('保存密码'),
                      value: _savePassword,
                      onChanged: (bool value) {
                        setState(() {
                          _savePassword = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // 错误提示
                    if (_errorMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],

                    // 解锁按钮
                    ElevatedButton(
                      onPressed: _isUnlocking ? null : _unlock,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isUnlocking
                          ? const CircularProgressIndicator()
                          : const Text('解锁'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 底部提示文本
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: const Text(
              '保存的密码将加密保存在本地，受主密码保护，且不会在任何地方显示。一旦主密码丢失将不可恢复。请自行记住密码。',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}