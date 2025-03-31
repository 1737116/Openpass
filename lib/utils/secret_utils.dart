import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

class AesKeyIv
{
  late encrypt.Key key;
  late encrypt.IV iv;

  AesKeyIv(encrypt.Key k, encrypt.IV i) {
    key = k;
    iv = i;
  }
}


// 测试: /test/utils/secret_utils_test.dart
class SecretUtils {
  static final _secureRandom = Random.secure(); // 单例安全实例，使用操作系统提供的CSPRNG

  static Uint8List _getSecureSeed() {
    return Uint8List.fromList(List.generate(32, (i) => _secureRandom.nextInt(256)));
  }

  // 生成指定长度的随机字节
  static Uint8List generateRandomBytes(int length) {
    return Uint8List.fromList(List<int>.generate(length, (_) => _secureRandom.nextInt(256)));
  }

  // 生成密码
  static String generatePassword(int passwordLength, bool includeNumbers, bool includeSymbols) {
    final chars = <String>[];
    chars.addAll(
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''));
    if (includeNumbers) chars.addAll('0123456789'.split(''));
    if (includeSymbols) chars.addAll('!@#\$%^&*(),.?":{}|<>'.split(''));

    return List.generate(passwordLength, (index) {
      return chars[_secureRandom.nextInt(chars.length)];
    }).join();
  }

  // 生成pin码（仅包含数字的密码）
  static String generatePin(int pinLength) {
    return List.generate(
      pinLength,
      (index) => _secureRandom.nextInt(10).toString(),
    ).join();
  }

  // 随机生成一个主密钥，格式为：MK-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX
  static String generateMasterKey() {
    final chars = <String>[];
    chars.addAll('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split(''));

    // 生成32个随机字符
    String key = List.generate(36, (index) {
      return chars[_secureRandom.nextInt(chars.length)];
    }).join();

    // 每6个字符插入一个连字符
    List<String> parts = [];
    for (int i = 0; i < key.length; i += 6) {
      parts.add(key.substring(i, min(i + 6, key.length)));
    }
    return 'MK-${parts.join('-')}';
  }

  static String getMasterKey(String masterKey) {
    masterKey = masterKey.trim();
    if (masterKey.length>3 && masterKey.startsWith('MK-')){
      masterKey = masterKey.substring(3);
    }
    return masterKey.replaceAll('-', '').replaceAll('\n', '');
  }

  // 生成 24 长度的保险库密码
  static String generateDatabasePassword() {
    return generatePassword(24, true, true);
  }

  // 生成 RSA 2048 密钥对
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateUserKeyPair() {
    final secureRandom = SecureRandom('Fortuna');
    secureRandom.seed(KeyParameter(_getSecureSeed()));

    var keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 12);
    var generator = RSAKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));
    return generator.generateKeyPair();
  }

  // 生成 RSA 2048 密钥对并转换为简单字符串格式
  static (String,String) generateUserKeyPairStr() {
    try {
      // 生成 RSA 密钥对
      final keyPair = generateUserKeyPair();

      // 将公钥和私钥转换为简单的 JSON 可存储格式
      final publicKey = keyPair.publicKey as RSAPublicKey;
      final privateKey = keyPair.privateKey as RSAPrivateKey;
      
      // 公钥只需保存模数和指数
      final publicKeyMap = {
        'modulus': publicKey.modulus.toString(),
        'exponent': publicKey.exponent.toString()
      };
      
      // 私钥需要保存所有组件
      final privateKeyMap = {
        'modulus': privateKey.modulus.toString(),
        'privateExponent': privateKey.privateExponent.toString(),
        'p': privateKey.p.toString(),
        'q': privateKey.q.toString()
      };
      
      // 转换为 JSON 字符串
      final publicKeyString = jsonEncode(publicKeyMap);
      final privateKeyString = jsonEncode(privateKeyMap);
      
      print('生成密钥对成功');
      return (publicKeyString, privateKeyString);
    } catch (e) {
      print('生成密钥对失败: $e');
    }
    return ('', '');
  }
  
  // 从字符串恢复 RSA 公钥
  static RSAPublicKey? publicKeyFromString(String publicKeyString) {
    try {
      final Map<String, dynamic> keyMap = jsonDecode(publicKeyString);
      final BigInt modulus = BigInt.parse(keyMap['modulus']);
      final BigInt exponent = BigInt.parse(keyMap['exponent']);
      
      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      print('恢复公钥失败: $e');
      return null;
    }
  }
  
  // 从字符串恢复 RSA 私钥
  static RSAPrivateKey? privateKeyFromString(String privateKeyString) {
    try {
      final Map<String, dynamic> keyMap = jsonDecode(privateKeyString);
      final BigInt modulus = BigInt.parse(keyMap['modulus']);
      final BigInt privateExponent = BigInt.parse(keyMap['privateExponent']);
      final BigInt p = BigInt.parse(keyMap['p']);
      final BigInt q = BigInt.parse(keyMap['q']);
      
      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      print('恢复私钥失败: $e');
      return null;
    }
  }
  

  // 简化版 SRP 协议参数生成
  static Map<String, Uint8List> generateSRPParameters(String accountDesc, String password) {
    var salt = generateAccountSalt(accountDesc);
    
    return {
      'salt': salt,
      'serverEphemeral': Uint8List.fromList(List.generate(32, (i) => _secureRandom.nextInt(256))),
      'clientEphemeral': Uint8List.fromList(List.generate(32, (i) => _secureRandom.nextInt(256))),
      'verifier': _computeVerifier(accountDesc, password, salt)
    };
  }

  // 基于账号信息生成盐值
  static Uint8List generateAccountSalt(String accountDesc) {
    var normalized = accountDesc.trim().toLowerCase();
    final saltedDesc = utf8.encode('$normalized wIhXHaw41Lv8KFI9cRwP');
    return SHA256Digest().process(saltedDesc);
  }

  // pmk推导
  //   pmk = PBKDF2-HMAC-SHA256(password, salt) ^ HKDF(masterKey, 32)
  static Uint8List pmkDerivation(String accountPassword, String masterKey, Uint8List salt, int iterationCount) {
    try {
      // 对账户密码进行规范化处理
      String normalizedPassword = accountPassword.trim();

      // 将密码转换为字节数组
      Uint8List passwordBytes = Uint8List.fromList(utf8.encode(normalizedPassword));

      int keyLength= 32;

      // 对 salt 进行 HKDF 处理，增强安全性
      KeyDerivator saltDerivator = HKDFKeyDerivator(SHA256Digest());
      saltDerivator.init(HkdfParameters(salt, keyLength, null, utf8.encode("salt_info")));
      Uint8List derivedSalt = saltDerivator.process(Uint8List(keyLength));

      // 使用 PBKDF2-HMAC-SHA256 处理密码和派生的盐
      KeyDerivator keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
      keyDerivator.init(Pbkdf2Parameters(derivedSalt, iterationCount, keyLength));
      Uint8List derivedPasswordKey = keyDerivator.process(passwordBytes);
      if (derivedPasswordKey.length!=32){
        throw Exception('PBKDF2 err');
      }

      // 对 masterKey 进行 HKDF 处理，增强安全性
      Uint8List masterKeyBytes = Uint8List.fromList(utf8.encode(getMasterKey(masterKey)));
      KeyDerivator hkdf = HKDFKeyDerivator(SHA256Digest());
      hkdf.init(HkdfParameters(masterKeyBytes, keyLength, null, utf8.encode("master_key_info")));
      Uint8List derivedMasterKey = hkdf.process(Uint8List(keyLength));
      if (derivedMasterKey.length!=32){
        throw Exception('HKDF err');
      }

      // 对派生的密码和主密钥进行异或操作
      Uint8List result = Uint8List(keyLength);
      for (int i = 0; i < keyLength; i++) {
        result[i] = derivedPasswordKey[i] ^ derivedMasterKey[i];
      }
      return result;
    } catch (e) {
      print('pmkDerivation $e');
    }
    return Uint8List(0);
  }

  // 加密数据
  //   encryptedData = AES-GCM(plainBytes, pmk)
  static Uint8List? encryptDataByPwdAndKey(Uint8List plainBytes, String accountPassword, String masterKey, Uint8List salt) {
    try {
      // 当前加密版本号
      int version = 1;
      int iterationCount = 650000;

      // 调试模式下降低迭代次数
      if (kDebugMode){
        version = 2;
        iterationCount = 6500;
        // print('encryptData');
        // print('Pwd: $accountPassword');
        // print('Key: $masterKey');
        // print('Sal: ${base64.encode(salt)}');
        // print('Cnt: $iterationCount');
      }


      // 使用 pmkDerivation 生成密钥
      Uint8List pmk = pmkDerivation(accountPassword, masterKey, salt, iterationCount);
      if (pmk.isEmpty) {
        print('PMK 生成失败');
        return null;
      }

      // 生成随机 IV (初始化向量)
      final iv = Uint8List.fromList(List.generate(16, (i) => _secureRandom.nextInt(256)));

      // 使用 encrypt 包进行加密，避免直接使用 GCMBlockCipher
      final encrypter = encrypt.Encrypter(encrypt.AES(
        encrypt.Key(pmk),
        mode: encrypt.AESMode.gcm,
      ));
      
      final encrypted = encrypter.encryptBytes(
        plainBytes,
        iv: encrypt.IV(iv),
      );

      // 将 IV 和密文组合在一起返回
      // 格式: [IV长度(1字节)][IV][密文]
      final result = Uint8List(2 + iv.length + encrypted.bytes.length);
      result[0] = version;
      result[1] = iv.length.toUnsigned(8);
      result.setRange(2, 2 + iv.length, iv);
      result.setRange(2 + iv.length, result.length, encrypted.bytes);
      
      return result;
    } catch (e) {
      print('encryptData error: $e');
      return null;
    }
  }

  // 解密数据
  //   plainBytes = AES-GCM-Decrypt(encryptedData, pmk)
  static Uint8List? decryptDataByPwdAndKey(Uint8List encryptedData, String accountPassword, String masterKey, Uint8List salt) {
    try {
      if (encryptedData.length < 3) {
        print('加密数据格式错误: 数据太短');
        return null;
      }

      // 读取版本号
      final version = encryptedData[0];
      int iterationCount = 650000;

      if (version==1 || version==2) {
        if (version==2) {
          iterationCount = 6500;
        }
        // if (kDebugMode) {
        //   print('decryptData');
        //   print('Pwd: $accountPassword');
        //   print('Key: $masterKey');
        //   print('Sal: ${base64.encode(salt)}');
        //   print('Cnt: $iterationCount');
        // }

        // 使用 pmkDerivation 生成密钥
        Uint8List pmk = pmkDerivation(accountPassword, masterKey, salt, iterationCount);
        if (pmk.isEmpty) {
          print('PMK 生成失败');
          return null;
        }
        
        // 从加密数据中提取 IV
        final ivLength = encryptedData[1];
        if (encryptedData.length < 2 + ivLength) {
          print('加密数据格式错误: IV 长度不正确');
          return null;
        }
        final iv = encryptedData.sublist(2, 2 + ivLength);
        final cipherText = encryptedData.sublist(2 + ivLength);

        // 使用 encrypt 包进行解密
        final encrypter = encrypt.Encrypter(encrypt.AES(
          encrypt.Key(pmk),
          mode: encrypt.AESMode.gcm,
        ));
        
        try {
          final decrypted = encrypter.decryptBytes(
            encrypt.Encrypted(cipherText),
            iv: encrypt.IV(iv),
          );
          
          return Uint8List.fromList(decrypted);
        } catch (e) {
          print('解密失败: $e');
          return null;
        }
      } else {
        print('不支持的加密版本: $version');
        return null;
      }
    } catch (e) {
      print('decryptData error: $e');
      return null;
    }
  }

  // 使用提供的密钥和IV加密数据
  static Uint8List? encryptWithKey(Uint8List data, Uint8List key, Uint8List iv) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.cbc,
      ));
      
      final encrypted = encrypter.encryptBytes(
        data,
        iv: encrypt.IV(iv),
      );
      
      return encrypted.bytes;
    } catch (e) {
      return null;
    }
  }

  // 使用提供的密钥和IV解密数据
  static Uint8List? decryptWithKey(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.cbc,
      ));
      
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedData),
        iv: encrypt.IV(iv),
      );
      
      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null;
    }
  }

  static Uint8List _computeVerifier(String accountDesc, String password, Uint8List salt) {
    var kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    kdf.init(Pbkdf2Parameters(salt, 100000, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  // 使用RSA公钥加密数据
  static String encryptWithRSA(String rsaPublicKeyStr, String data) {
    try {
      // 从字符串恢复RSA公钥
      final publicKey = publicKeyFromString(rsaPublicKeyStr);
      if (publicKey == null) {
        throw Exception('无效的RSA公钥');
      }

      // 创建RSA加密器
      final cipher = RSAEngine()
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      // 将数据转换为字节
      final dataBytes = utf8.encode(data);
      
      // 由于RSA加密有大小限制，需要分块加密
      // RSA-2048 最大可加密字节数约为 (2048/8 - 11) = 245字节
      final blockSize = (publicKey.modulus!.bitLength ~/ 8) - 11;
      final result = <int>[];
      
      // 分块加密
      for (var i = 0; i < dataBytes.length; i += blockSize) {
        final blockEnd = i + blockSize > dataBytes.length ? dataBytes.length : i + blockSize;
        final block = dataBytes.sublist(i, blockEnd);
        final encryptedBlock = cipher.process(Uint8List.fromList(block));
        result.addAll(encryptedBlock);
      }
      
      // 返回Base64编码的加密数据
      return base64.encode(result);
    } catch (e) {
      print('RSA加密失败: $e');
      return '';
    }
  }

  // 使用RSA私钥解密数据
  static String? decryptWithRSA(String rsaPrivateKeyStr, String encryptedData) {
    try {
      // 从字符串恢复RSA私钥
      final privateKey = privateKeyFromString(rsaPrivateKeyStr);
      if (privateKey == null) {
        throw Exception('无效的RSA私钥');
      }

      // 创建RSA解密器
      final cipher = RSAEngine()
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      // 将Base64编码的加密数据转换为字节
      final encryptedBytes = base64.decode(encryptedData);
      
      // 由于RSA解密需要分块处理
      // RSA-2048 每块大小为 2048/8 = 256字节
      final blockSize = privateKey.modulus!.bitLength ~/ 8;
      final result = <int>[];
      
      // 分块解密
      for (var i = 0; i < encryptedBytes.length; i += blockSize) {
        final blockEnd = i + blockSize > encryptedBytes.length ? encryptedBytes.length : i + blockSize;
        final block = encryptedBytes.sublist(i, blockEnd);
        final decryptedBlock = cipher.process(Uint8List.fromList(block));
        result.addAll(decryptedBlock);
      }
      
      // 返回解密后的字符串
      return utf8.decode(result);
    } catch (e) {
      print('RSA解密失败: $e');
      return null;
    }
  }

  static String aesEncryptFilename(AesKeyIv aesKeyIv, String filename) {
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKeyIv.key));
    final encrypted = encrypter.encrypt(filename, iv: aesKeyIv.iv);
    return encrypted.base64.replaceAll('/', '_').replaceAll('+', '-');
  }

  static String aesDecryptFilename(AesKeyIv aesKeyIv, String encryptedFilename) {
    final sanitized = encryptedFilename.replaceAll('_', '/').replaceAll('-', '+');
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKeyIv.key));
    final decrypted = encrypter.decrypt64(sanitized, iv: aesKeyIv.iv);
    return decrypted;
  }
  
  static Uint8List aesEncryptBytes(AesKeyIv aesKeyIv, Uint8List content) {
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKeyIv.key));
    final encrypted = encrypter.encryptBytes(content, iv: aesKeyIv.iv);
    return encrypted.bytes;
  }

  static Uint8List aesDecryptBytes(AesKeyIv aesKeyIv, Uint8List encryptedContent) {
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKeyIv.key));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedContent),
      iv: aesKeyIv.iv);
    return Uint8List.fromList(decrypted);
  }
  
}
