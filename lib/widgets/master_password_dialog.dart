import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

class MasterPasswordDialog extends StatefulWidget {
  final Future<bool> Function(String currentPassword)? validateCurrentPassword;
  
  const MasterPasswordDialog({
    super.key,
    this.validateCurrentPassword,
  });

  @override
  State<MasterPasswordDialog> createState() => _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends State<MasterPasswordDialog> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSubmit() async {
    // 重置错误信息
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      // 验证当前密码
      if (widget.validateCurrentPassword != null) {
        bool isValid = await widget.validateCurrentPassword!(_currentPasswordController.text);
        if (!isValid) {
          setState(() {
            _errorMessage = '当前密码不正确';
            _isProcessing = false;
          });
          return;
        }
      }

      // 验证新密码
      if (_newPasswordController.text.isEmpty) {
        setState(() {
          _errorMessage = '新密码不能为空';
          _isProcessing = false;
        });
        return;
      }

      // 验证密码长度
      if (_newPasswordController.text.length < 8) {
        setState(() {
          _errorMessage = '新密码长度不能少于8个字符';
          _isProcessing = false;
        });
        return;
      }

      // 验证密码确认
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = '两次输入的密码不一致';
          _isProcessing = false;
        });
        return;
      }

      // 返回新密码
      Navigator.of(context).pop(_newPasswordController.text);
    } catch (e) {
      setState(() {
        _errorMessage = '验证过程中出错: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改主密码'),
      content: Container(
        width: 400,
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '主密码用于加密您的所有保险库数据，请确保密码强度并妥善保管。',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              
              // 当前密码输入框
              if (widget.validateCurrentPassword != null) ...[
                TextField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: '当前密码',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _showCurrentPassword = !_showCurrentPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showCurrentPassword,
                ),
                const SizedBox(height: 16),
              ],
              
              // 新密码输入框
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: '新密码',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNewPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showNewPassword = !_showNewPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showNewPassword,
              ),
              const SizedBox(height: 16),
              
              // 确认密码输入框
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '确认新密码',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showConfirmPassword,
              ),
              
              // 密码强度指示器
              const SizedBox(height: 16),
              _buildPasswordStrengthIndicator(),
              
              // 错误信息
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _validateAndSubmit,
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认修改'),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    // 计算密码强度
    String password = _newPasswordController.text;
    double strength = 0;
    
    if (password.isNotEmpty) {
      // 基础长度分数
      strength += password.length * 0.1;
      
      // 包含数字
      if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
      
      // 包含小写字母
      if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.2;
      
      // 包含大写字母
      if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
      
      // 包含特殊字符
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;
    }
    
    // 限制最大值为1.0
    strength = strength > 1.0 ? 1.0 : strength;
    
    // 确定强度级别和颜色
    Color strengthColor;
    String strengthText;
    
    if (strength < 0.3) {
      strengthColor = Colors.red;
      strengthText = '弱';
    } else if (strength < 0.7) {
      strengthColor = Colors.orange;
      strengthText = '中';
    } else {
      strengthColor = Colors.green;
      strengthText = '强';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('密码强度: ', style: TextStyle(fontSize: 14)),
            Text(
              strengthText,
              style: TextStyle(
                color: strengthColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
        ),
        const SizedBox(height: 8),
        const Text(
          '提示: 强密码应包含大小写字母、数字和特殊字符',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}