import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class KeyImportDialog extends StatefulWidget {
  final String? initialValue;
  const KeyImportDialog({super.key, this.initialValue});

  @override
  State<KeyImportDialog> createState() => _KeyImportDialogState();
}

class _KeyImportDialogState extends State<KeyImportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _importKeyFile() async {
    // 仅在Android平台上请求存储权限
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          // 用户拒绝了权限请求
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要存储权限才能导入文件')),
            );
          }
          return;
        }
      }
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // 直接获取文件数据，避免路径问题
      );

      if (result != null && result.files.isNotEmpty) {
        if (result.files.single.bytes != null) {
          // 直接使用文件字节数据
          final bytes = result.files.single.bytes!;
          try {
            // 尝试以文本方式解析
            final content = utf8.decode(bytes);
            setState(() {
              _controller.text = content;
            });
          } catch (e) {
            // 如果文本解析失败，则转换为 base64
            final base64Content = base64Encode(bytes);
            setState(() {
              _controller.text = base64Content;
            });
          }
        } else if (result.files.single.path != null) {
          // 使用文件路径
          final file = File(result.files.single.path!);
          try {
            // 尝试以文本方式读取文件
            final content = await file.readAsString();
            setState(() {
              _controller.text = content;
            });
          } catch (e) {
            // 如果文本读取失败，则以二进制方式读取并转换为 base64
            final bytes = await file.readAsBytes();
            final base64Content = base64Encode(bytes);
            setState(() {
              _controller.text = base64Content;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件选择失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      child: Container(
        width: size.width * 0.8,
        height: size.height * 0.6,
        padding: EdgeInsets.all(size.width * 0.02),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '导入密钥',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                scrollPhysics: const ClampingScrollPhysics(),
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入或导入密钥内容',
                  alignLabelWithHint: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _importKeyFile,
                  child: const Text('导入'),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final text = _controller.text;
                    Navigator.pop(context, text);
                  },
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}