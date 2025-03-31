import 'dart:io';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/key_import_dialog.dart';

class NewDatabasePage extends ConsumerStatefulWidget {
  const NewDatabasePage({super.key});

  @override
  ConsumerState<NewDatabasePage> createState() => _NewDatabasePageState();
}

class _NewDatabasePageState extends ConsumerState<NewDatabasePage> {
  static final _log = Logger('NewDatabasePage');
  // 打开模式的状态
  final TextEditingController _openPasswordController = TextEditingController();
  String? _openFilePath;
  String? _openKeyData;

  // 新建模式的状态
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  // String? _newFilePath;
  String? _newKeyData;
  IconData _selectedIcon = Icons.lock;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _localFiles = [];

  final FocusNode _passwordFocusNode = FocusNode();
  bool _isCreating = false;
  bool _isNewDatabase = true;
  bool _isPickerOpened = false;
  String? _errorMessage;

  // 获取当前模式的文件路径和密钥
  // String? get _currentFilePath => _isNewDatabase ? _newFilePath : _openFilePath;
  String? get _currentKeyData => _isNewDatabase ? _newKeyData : _openKeyData;

  @override
  void initState() {
    super.initState();
    _loadLocalFiles();
  }

  @override
  void dispose() {
    _openPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLocalFiles() async {
    final keepassFileService = ref.read(keepassFileServiceProvider);
    final itemListService = ref.read(itemListServiceProvider);
    final files = await keepassFileService.listLocalFiles();
    setState(() {
      _localFiles = files
          .where((path) => itemListService.opRoot.findDatabaseByPath(path) == null)
          .toList();
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 更新密钥数据
  void _updateKeyData(String? keyData) {
    setState(() {
      if (_isNewDatabase) {
        _newKeyData = keyData;
      } else {
        _openKeyData = keyData;
      }
    });
  }

  Future<void> _showKeyImportDialog() async {
    String? result = await showDialog<String>(
      context: context,
      builder: (context) => KeyImportDialog(
        initialValue: _currentKeyData,
      ),
    );

    if (result != null) {
      setState(() {
        _updateKeyData(result.isEmpty ? null : result);
      });
    }
  }

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  bool _checkDatabaseExist() {
    final itemListService = ref.read(itemListServiceProvider);
    if (itemListService.opRoot.findDatabaseByPath(_openFilePath!) != null) {
      _showError('此保险库已存在');
      return false;
    }
    return true;
  }

  Future<void> _openDatabase() async {
    final itemListService = ref.read(itemListServiceProvider);
    if (_openFilePath == null) {
      _showError('请选择密码库文件');
      return;
    }

    if (!_checkDatabaseExist()) {
      return;
    }

    if (_openPasswordController.text.isEmpty) {
      _showError('请输入密码');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isCreating = true;
    });

    try {
      // 打开数据库的具体实现
      final result = await itemListService.addDatabase(
          _openFilePath!, _openPasswordController.text, _openKeyData, false);
      if (!result) {
        _showError('密码错误');
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError('打开失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('增加保险库'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, minWidth: 300),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 切换按钮组
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('本地保险库'),
                        value: true,
                        groupValue: _isNewDatabase,
                        onChanged: (bool? value) {
                          if (value != null && value != _isNewDatabase) {
                            setState(() {
                              _isNewDatabase = value;
                            });
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('外部保险库'),
                        value: false,
                        groupValue: _isNewDatabase,
                        onChanged: (bool? value) {
                          if (value != null && value != _isNewDatabase) {
                            setState(() {
                              _isNewDatabase = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 根据模式显示不同的表单
                _isNewDatabase
                    ? _buildNewDatabaseForm()
                    : _buildOpenDatabaseForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建打开保险库的界面
  Widget _buildOpenDatabaseForm() {
    return Column(
      children: [
        // 文件选择
        TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: '选择密码库',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.folder_open),
            suffixIcon: IconButton(
              icon: Icon(
                _openKeyData != null ? Icons.key : Icons.key_outlined,
                color: _openKeyData != null ? Colors.blue : null,
              ),
              onPressed: _showKeyImportDialog,
              tooltip: '导入密钥文件',
            ),
          ),
          controller: TextEditingController(
            text: _openFilePath != null ? _getFileName(_openFilePath!) : '',
          ),
          onTap: () async {
            if (!_isPickerOpened) {
              _isPickerOpened = true;
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['kdbx'],
              );

              if (result != null) {
                setState(() {
                  _openFilePath = result.files.single.path!;
                  _checkDatabaseExist();
                });
              }
              _isPickerOpened = false;
            }
          },
        ),
        const SizedBox(height: 16),

        // 密码输入框
        TextField(
          controller: _openPasswordController,
          focusNode: _passwordFocusNode,
          decoration: const InputDecoration(
            labelText: '密码',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),

        if (_errorMessage != null) _buildErrorMessage(),
        const SizedBox(height: 32),

        // 打开按钮
        ElevatedButton(
          onPressed: _isCreating ? null : _openDatabase,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: _isCreating
              ? const CircularProgressIndicator()
              : const Text('打开'),
        ),
      ],
    );
  }

  // 构建新建保险库的界面
  Widget _buildNewDatabaseForm() {
    return Column(
      children: [
        // 创建卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('创建新保险库',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // 图标选择
                ListTile(
                  leading: Icon(_selectedIcon, size: 32),
                  title: const Text('选择图标'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    // final result = await Navigator.push<IconData>(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => IconManagePage(
                    //       currentIcon: _selectedIcon,
                    //     ),
                    //   ),
                    // );
                    // if (result != null) {
                    //   setState(() {
                    //     _selectedIcon = result;
                    //   });
                    // }
                  },
                ),
                const SizedBox(height: 16),
                // 保险库名称
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '保险库名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                ),
                const SizedBox(height: 16),
                // 保险库描述
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 现有本地保险库列表
        if (_localFiles.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('发现本地保险库',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...(_localFiles.map((path) => ListTile(
                        leading: const Icon(Icons.lock),
                        title: Text(_getFileName(path),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: FutureBuilder<String>(
                          future: File(path).lastModified().then((date) =>
                              '最后修改：${date.toString().substring(0, 19)}'),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? '正在获取修改时间...',
                              maxLines: 1,
                            );
                          },
                        ),
                        onTap: () {
                          // TODO: 处理本地文件导入
                        },
                      ))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_errorMessage != null) _buildErrorMessage(),
        const SizedBox(height: 32),

        // 创建按钮
        ElevatedButton(
          onPressed: _isCreating ? null : _createLocalDatabase,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: _isCreating
              ? const CircularProgressIndicator()
              : const Text('创建'),
        ),
      ],
    );
  }

  // 创建本地数据库
  Future<void> _createLocalDatabase() async {
    if (_nameController.text.isEmpty) {
      _showError('请输入保险库名称');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isCreating = true;
    });


    try {
      // 生成文件路径
      final localStorageService = ref.read(localStorageServiceProvider);
      final fileName = await localStorageService.getNewDatabaseFilename();
      final filePath = '#/$fileName';

      // 生成随机密码
      final password = const Uuid().v4();

      final dbName = _nameController.text;
      final dbDesc = _descriptionController.text;

      _log.info('createLocalDatabase:');
      _log.info('- filePath: $filePath');
      _log.info('- password: $password');
      _log.info('- name: $dbName');
      _log.info('- desc: $dbDesc');

      // 创建数据库
      final keepassFileService = ref.read(keepassFileServiceProvider);
      final itemListService = ref.read(itemListServiceProvider);
      final success = await keepassFileService.createKeePassFile(
        itemListService.opRoot,
        filePath,
        dbName,
        dbDesc,
        _selectedIcon,
        password,
      );

      if (!success) {
        throw Exception('创建数据库失败');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError('创建失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 14,
        ),
      ),
    );
  }
}
