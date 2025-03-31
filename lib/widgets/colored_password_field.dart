import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ColoredPasswordField extends StatefulWidget {
  final String password;
  final ValueChanged<String>? onChanged;

  const ColoredPasswordField({
    super.key,
    required this.password,
    this.onChanged,
  });

  @override
  State<ColoredPasswordField> createState() => _ColoredPasswordFieldState();
}

class _ColoredPasswordFieldState extends State<ColoredPasswordField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.password);
    _isInitialized = true;
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ColoredPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized && widget.password != oldWidget.password && widget.password != _controller.text) {
      // 保存当前光标位置
      final selection = _controller.selection;
      _controller.text = widget.password;
      // 恢复光标位置
      _controller.selection = selection;
    }
    // if (widget.password != _controller.text) {
    //   _controller.text = widget.password;
    // }
  }

  @override
  Widget build(BuildContext context) {
    final themeExtension = Theme.of(context).extension<AppThemeExtension>();
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: !_focusNode.hasFocus,
      enabled: true,
      style: TextStyle(
        fontFamily: themeExtension?.passwordFontFamily,
        fontSize: themeExtension?.passwordFontSize,
        color: _focusNode.hasFocus ? Colors.black : null,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none, //UnderlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
      ),
      onChanged: (value) {
        // setState(() {
        //   _controller.text = value;
        //   widget.onChanged?.call(value);
        // });
        widget.onChanged?.call(value);
      },
    );
  }
}