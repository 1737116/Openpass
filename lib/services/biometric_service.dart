import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';

class BiometricService {
  static final _log = Logger('BiometricService');
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isChecked = false;
  bool _canCheckBiometrics = false;
  bool _isBiometricOnly = true;
  BiometricType? _biometricType;

  bool get canCheckBiometrics => _canCheckBiometrics;
  bool get isBiometricOnly => _isBiometricOnly;
  BiometricType? get biometricType => _biometricType;
  bool get isChecked => _isChecked;

  // 检查设备是否支持生物识别
  Future<bool> checkBiometrics() async {
    if (_isChecked) {
      return _canCheckBiometrics;
    }
    
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      _log.info('Biometric support status:');
      _log.info('- Can check biometrics: $canCheck');
      _log.info('- Device supported: $isDeviceSupported');
      _log.info('- Available biometrics: $availableBiometrics');
      
      if (Platform.isWindows) {
        _log.info('Windows authentication options:');
        for (var type in availableBiometrics) {
          _log.info('  - ${type.toString()}');
        }
      }
      
      _canCheckBiometrics = canCheck && isDeviceSupported;
      if (availableBiometrics.isNotEmpty) {
        if (Platform.isWindows) {
          _isBiometricOnly = false;
          if (availableBiometrics.contains(BiometricType.face)) {
            _biometricType = BiometricType.face;  // Windows Hello Face
            _log.info('Selected: Windows Hello Face');
          } else if (availableBiometrics.contains(BiometricType.strong)) {
            _biometricType = BiometricType.strong;  // Windows Hello PIN
            _log.info('Selected: Windows Hello PIN');
          } else if (availableBiometrics.contains(BiometricType.weak)) {
            _biometricType = BiometricType.weak;  // Windows Hello PIN
            _log.info('Selected: Windows Hello PIN');
          } 
        } else if (availableBiometrics.contains(BiometricType.face)) {
          _biometricType = BiometricType.face;
          _log.info('Selected: Face recognition');
        } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
          _biometricType = BiometricType.fingerprint;
          _log.info('Selected: Fingerprint');
        } 
      }
      
      _isChecked = true;
      return _canCheckBiometrics;
    } on PlatformException catch (e) {
      _log.warning('Biometric check failed', e);
      _canCheckBiometrics = false;
      _isChecked = true;
      return false;
    }
  }

  bool isEnabled() {
    return _canCheckBiometrics && _biometricType!=null;
  }

  int getTypeCode() {
    int type = 0;
    if (_biometricType!=null) {
      switch (_biometricType!) {
      case BiometricType.face:
        type = 1;
        break;
      case BiometricType.fingerprint:
        type = 2;
        break;
      case BiometricType.strong:
        type = 3;
        break;
      case BiometricType.weak:
        type = 4;
        break;
      default:
        type = 0;
        break;
      }
    }
    return type;
  }

  // 使用生物识别进行认证
  Future<bool> authenticate({String reason = '请使用生物识别进行身份验证'}) async {
    if (!_canCheckBiometrics || _biometricType == null) {
      return false;
    }
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: _isBiometricOnly,
        ),
      );
      
      if (authenticated) {
        _log.info('生物识别认证成功');
      } else {
        _log.info('生物识别认证失败或被取消');
      }
      
      return authenticated;
    } on PlatformException catch (e) {
      _log.warning('生物识别认证出错: ${e.message}');
      return false;
    }
  }

  // 获取生物识别图标
  IconData getBiometricIcon() {
    if (Platform.isWindows) {
      if (_biometricType == BiometricType.strong) {
        return Icons.pin_outlined;  // Windows Hello PIN
      } else if (_biometricType == BiometricType.face) {
        return Icons.face_retouching_natural;  // Windows Hello Face
      }
    } else if (_biometricType == BiometricType.fingerprint) {
      return Icons.fingerprint;
    } else if (_biometricType == BiometricType.face) {
      return Icons.face_retouching_natural;
    }
    return Icons.fingerprint;  // 默认图标
  }

  // 获取生物识别提示文本
  String getBiometricTooltip() {
    if (Platform.isWindows) {
      if (_biometricType == BiometricType.strong) {
        return 'Windows Hello PIN';
      } else if (_biometricType == BiometricType.face) {
        return 'Windows Hello 面部识别';
      }
    } else if (_biometricType == BiometricType.fingerprint) {
      return '指纹识别';
    } else if (_biometricType == BiometricType.face) {
      return '人脸识别';
    }
    return '生物识别';
  }
}