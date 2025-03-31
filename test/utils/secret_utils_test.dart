import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openpass_cloud/utils/secret_utils.dart';

void main() {
  group('SecretUtils Tests', () {
    test('Generate Master Key', () {
      final masterKey = SecretUtils.generateMasterKey();
      expect(masterKey.startsWith('MK-'), true);
      expect(masterKey.split('-').length, 7); // MK + 6个部分
    });

    test('Generate Password', () {
      final password = SecretUtils.generatePassword(12, true, true);
      expect(password.length, 12);
    });

    test('Generate PIN', () {
      final pin = SecretUtils.generatePin(6);
      expect(pin.length, 6);
      expect(int.tryParse(pin) != null, true); // 确保是数字
    });

    test('Generate User Key Pair', () {
      final (publicKey, privateKey) = SecretUtils.generateUserKeyPairStr();
      expect(publicKey.isNotEmpty, true);
      expect(privateKey.isNotEmpty, true);
      
      // 测试密钥恢复
      final recoveredPublicKey = SecretUtils.publicKeyFromString(publicKey);
      final recoveredPrivateKey = SecretUtils.privateKeyFromString(privateKey);
      expect(recoveredPublicKey != null, true);
      expect(recoveredPrivateKey != null, true);
    });

    test('PMK Derivation', () {
      final password = "test_password";
      final masterKey = "MK-ABCDEF-GHIJKL-MNOPQR-STUVWX-YZ1234-567890";
      final salt = SecretUtils.generateRandomBytes(16);
      
      final pmk = SecretUtils.pmkDerivation(password, masterKey, salt, 6500);
      expect(pmk.length, 32); // 应该生成32字节的密钥
    });

    test('Encrypt and Decrypt Data', () {
      final password = "test_password";
      final masterKey = SecretUtils.generateMasterKey();
      final salt = SecretUtils.generateRandomBytes(16);
      String testData = "这是一段测试数据，包含中文和特殊字符!@#\$%^&*()";

      final plainBytes = Uint8List.fromList(utf8.encode(testData));

      // 加密
      final encryptedData = SecretUtils.encryptDataByPwdAndKey(plainBytes, password, masterKey, salt);
      expect(encryptedData != null, true);
      
      // 解密
      final decryptedData = SecretUtils.decryptDataByPwdAndKey(encryptedData!, password, masterKey, salt);
      expect(decryptedData != null, true);
      expect(utf8.decode(decryptedData!), testData);
      
      // 错误密码测试
      final wrongDecrypted = SecretUtils.decryptDataByPwdAndKey(encryptedData, "wrong_password", masterKey, salt);
      expect(wrongDecrypted == null, true);
    });

    test('Memory Encryption', () {
      final key = SecretUtils.generateRandomBytes(32);
      final iv = SecretUtils.generateRandomBytes(16);
      final data = Uint8List.fromList(utf8.encode("内存加密测试"));
      
      // 加密
      final encrypted = SecretUtils.encryptWithKey(data, key, iv);
      expect(encrypted != null, true);
      
      // 解密
      final decrypted = SecretUtils.decryptWithKey(encrypted!, key, iv);
      expect(decrypted != null, true);
      expect(utf8.decode(decrypted!), "内存加密测试");
    });

    test('Tamper Resistance', () {
      final password = "test_password";
      final masterKey = SecretUtils.generateMasterKey();
      final salt = SecretUtils.generateRandomBytes(16);
      final originalData = Uint8List.fromList(utf8.encode("完整性测试数据"));
      
      // 加密
      final encryptedData = SecretUtils.encryptDataByPwdAndKey(originalData, password, masterKey, salt);
      expect(encryptedData != null, true);
      
      // 篡改密文
      final tamperedData = Uint8List.fromList(encryptedData!);
      int ivLength = tamperedData[0];
      tamperedData[ivLength + 10] = (tamperedData[ivLength + 10] + 1) % 256;
      
      // 尝试解密被篡改的数据
      final tamperedDecrypted = SecretUtils.decryptDataByPwdAndKey(tamperedData, password, masterKey, salt);
      expect(tamperedDecrypted == null, true); // 应该解密失败
    });

    test('RSA Encryption and Decryption', () {
      // 生成RSA密钥对
      final (publicKey, privateKey) = SecretUtils.generateUserKeyPairStr();
      expect(publicKey.isNotEmpty, true);
      expect(privateKey.isNotEmpty, true);
      
      // 测试多组不同长度和内容的数据
      final testDataSets = [
        "这是一段简短的测试数据",
        "这是一段较长的测试数据，包含中文、数字123和特殊字符!@#\$%^&*()",
        "这是一段非常长的测试数据，用于测试分块加密解密功能。" * 20, // 重复20次以创建大数据
        json.encode({"key1": "value1", "key2": 123, "key3": true, "key4": ["a", "b", "c"]}),
        SecretUtils.generatePassword(200, true, true), // 随机生成的长密码
      ];
      
      for (int i = 0; i < testDataSets.length; i++) {
        final testData = testDataSets[i];
        
        // 加密
        final encrypted = SecretUtils.encryptWithRSA(publicKey, testData);
        expect(encrypted.isNotEmpty, true, reason: "第${i+1}组数据加密失败");
        
        // 解密
        final decrypted = SecretUtils.decryptWithRSA(privateKey, encrypted);
        expect(decrypted != null, true, reason: "第${i+1}组数据解密失败");
        expect(decrypted, testData, reason: "第${i+1}组数据解密结果不匹配");
      }
    });
    
    test('RSA Encryption with Multiple Random Keys', () {
      // 测试多组随机生成的密钥对
      for (int i = 0; i < 5; i++) {
        // 生成RSA密钥对
        final (publicKey, privateKey) = SecretUtils.generateUserKeyPairStr();
        
        // 生成随机测试数据
        final testData = SecretUtils.generatePassword(50 + i * 30, true, true);
        
        // 加密
        final encrypted = SecretUtils.encryptWithRSA(publicKey, testData);
        expect(encrypted.isNotEmpty, true, reason: "第${i+1}组随机密钥加密失败");
        
        // 解密
        final decrypted = SecretUtils.decryptWithRSA(privateKey, encrypted);
        expect(decrypted != null, true, reason: "第${i+1}组随机密钥解密失败");
        expect(decrypted, testData, reason: "第${i+1}组随机密钥解密结果不匹配");
        
        // 使用错误的私钥尝试解密
        if (i > 0) {
          final (_, wrongPrivateKey) = SecretUtils.generateUserKeyPairStr();
          final wrongDecrypted = SecretUtils.decryptWithRSA(wrongPrivateKey, encrypted);
          // 使用错误私钥应该解密失败或结果不匹配
          expect(wrongDecrypted != testData, true, reason: "使用错误私钥仍能正确解密");
        }
      }
    });
    
    test('RSA Cross-Compatibility Test', () {
      // 测试加密和解密的跨兼容性
      final keyPairs = List.generate(3, (_) => SecretUtils.generateUserKeyPairStr());
      final testData = "跨密钥测试数据 - ${DateTime.now()}";
      
      // 使用不同的公钥加密同一数据
      final encryptedDataList = keyPairs.map((pair) => 
          SecretUtils.encryptWithRSA(pair.$1, testData)).toList();
      
      // 确保每个加密结果都可以用对应的私钥解密
      for (int i = 0; i < keyPairs.length; i++) {
        final decrypted = SecretUtils.decryptWithRSA(keyPairs[i].$2, encryptedDataList[i]);
        expect(decrypted, testData, reason: "第${i+1}对密钥的加解密结果不匹配");
      }
      
      // 确保使用错误的私钥无法正确解密
      for (int i = 0; i < keyPairs.length; i++) {
        for (int j = 0; j < keyPairs.length; j++) {
          if (i != j) {
            final wrongDecrypted = SecretUtils.decryptWithRSA(keyPairs[j].$2, encryptedDataList[i]);
            // 使用不匹配的私钥应该解密失败或结果不匹配
            expect(wrongDecrypted != testData, true, reason: "使用不匹配的私钥仍能正确解密");
          }
        }
      }
    });
  });
}