import 'dart:io';
// import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../widgets/key_import_dialog.dart';
import '../models/database_model.dart';

class ImportKdbxDatabasePage extends ConsumerStatefulWidget {
  final OPDatabase targetDatabase; // 导入到的目标数据库
  
  const ImportKdbxDatabasePage({
    super.key,
    required this.targetDatabase,
  });

  @override
  ConsumerState<ImportKdbxDatabasePage> createState() => _ImportKdbxDatabasePageState();
}

class _ImportKdbxDatabasePageState extends ConsumerState<ImportKdbxDatabasePage> {
  // static final _log = Logger('ImportKdbxDatabasePage');
  
  final TextEditingController _passwordController = TextEditingController();
  String? _filePath;
  String? _keyData;

  final FocusNode _passwordFocusNode = FocusNode();
  bool _isImporting = false;
  bool _isPickerOpened = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  Future<void> _importDatabase() async {
    final itemListService = ref.read(itemListServiceProvider);
    
    if (_filePath == null) {
      _showError('请选择密码库文件');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('请输入密码');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isImporting = true;
    });

    try {
      // 导入数据库的具体实现
      final result = await itemListService.importKdbx(
        widget.targetDatabase,
        _filePath!,
        _passwordController.text,
        _keyData,
      );
      
      if (!result) {
        _showError('导入失败，可能是密码错误');
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError('导入失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入 KDBX 数据库'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, minWidth: 300),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '导入到: ${widget.targetDatabase.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                _buildImportForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportForm() {
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
                _keyData != null ? Icons.key : Icons.key_outlined,
                color: _keyData != null ? Colors.blue : null,
              ),
              onPressed: _showKeyImportDialog,
              tooltip: '导入密钥文件',
            ),
          ),
          controller: TextEditingController(
            text: _filePath != null ? _getFileName(_filePath!) : '',
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
                  _filePath = result.files.single.path!;
                });
              }
              _isPickerOpened = false;
            }
          },
        ),
        const SizedBox(height: 16),

        // 密码输入框
        TextField(
          controller: _passwordController,
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

        // 导入按钮
        ElevatedButton(
          onPressed: _isImporting ? null : _importDatabase,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: _isImporting
              ? const CircularProgressIndicator()
              : const Text('导入'),
        ),
      ],
    );
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