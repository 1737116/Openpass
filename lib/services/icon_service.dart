import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import '../services/local_storage_service.dart';
import '../utils/secret_utils.dart';
import '../models/op_icon.dart';

class IconService {
  static final Set<String> _failedUrls = <String>{};
  static const int _maxMemoryCacheSize = 100;
  final LocalStorageService _localStorageService;
  late CacheManager cacheManager;
  final Map<String, OPIcon> _memoryCache = {};
  final List<String> _memoryCacheKeys = [];
  
  // 加密密钥
  late AesKeyIv _filenameKey;
  late AesKeyIv _contentKey;
  bool _keysInitialized = false;
  
  
  IconService(this._localStorageService) {
    // 初始化缓存管理器
    _initCacheManager();
    
    // 初始化加密密钥
    _initEncryptionKeys();
  }
  
  // 初始化缓存管理器
  Future<void> _initCacheManager() async {
    try {
      // 获取应用文档目录
      final iconCacheDir = await _localStorageService.getIconCacheDir();
      
      // 创建自定义缓存管理器
      cacheManager = CacheManager(
        Config(
          'faviconCache',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 200,
          repo: JsonCacheInfoRepository(databaseName: 'faviconCache'),
          fileService: HttpFileService(),
          fileSystem: IOFileSystem(iconCacheDir.path),
        ),
      );
    } catch (e) {
      // 如果自定义缓存管理器初始化失败，使用默认的
      cacheManager = DefaultCacheManager();
    }
  }
  
  // 添加检查和标记失败URL的方法
  static bool isFailedUrl(String url) {
    return _failedUrls.contains(url);
  }

  static void markFailedUrl(String url) {
    _failedUrls.add(url);
  }
  // 初始化加密密钥
  Future<void> _initEncryptionKeys() async {
    if (_keysInitialized) return;
    
    try {
      // 尝试从存储中获取密钥
      var k1 = await _localStorageService.getEncryptionKey('faviconFilenameKey', true);
      if (k1 == null) {
        throw Exception('getEncryptionKey err');
      }
      _filenameKey = k1;

      var k2 = await _localStorageService.getEncryptionKey('faviconContentKey', true);
      if (k2 == null) {
        throw Exception('getEncryptionKey err');
      }
      _contentKey = k2;

      _keysInitialized = true;
    } catch (e) {
      // 无法处理
    }
  }

  // 加密文件名
  String _encryptFilename(String filename) {
    if (!_keysInitialized) {
      throw Exception('加密密钥尚未初始化');
    }
    return SecretUtils.aesEncryptFilename(_filenameKey, filename);
  }
  
  // // 解密文件名
  // String _decryptFilename(String encryptedFilename) {
  //   if (!_keysInitialized) {
  //     throw Exception('加密密钥尚未初始化');
  //   }
  //   return SecretUtils.aesDecryptFilename(_filenameKey, encryptedFilename);
  // }
  
  // 加密文件内容
  Uint8List _encryptContent(Uint8List content) {
    if (!_keysInitialized) {
      throw Exception('加密密钥尚未初始化');
    }
    return SecretUtils.aesEncryptBytes(_contentKey, content);
  }
  
  // 解密文件内容
  Uint8List _decryptContent(Uint8List encryptedContent) {
    if (!_keysInitialized) {
      throw Exception('加密密钥尚未初始化');
    }
    return SecretUtils.aesDecryptBytes(_contentKey, encryptedContent);
  }

  // 获取网站图标，传入的必须是全小写并只包含域名
  Future<OPIcon?> getIconFromUrl(String normalizedUrl) async {
    if (!(normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://'))) {
      return null;
    }

    // 确保密钥已初始化
    await _initEncryptionKeys();
    
    // 生成唯一ID
    final iconId = _generateIconId(normalizedUrl);
    
    // 首先检查内存缓存
    if (_memoryCache.containsKey(iconId)) {
      // 更新LRU顺序
      _memoryCacheKeys.remove(iconId);
      _memoryCacheKeys.add(iconId);
      return _memoryCache[iconId]!;
    }

    // 加密后的缓存ID
    final encryptedIconId = _encryptFilename(iconId);

    // 检查本地缓存
    final cachedIcon = await _getFromCache(encryptedIconId);
    if (cachedIcon != null) {
      // 添加到内存缓存
      final opIcon = OPIcon(
        iconId: iconId,
        image: cachedIcon,
        fromCache: true,
      );
      _addToMemoryCache(iconId, opIcon);
      return opIcon;
    }
    
    // 尝试从网站获取图标
    try {
      // 尝试不同的favicon路径
      final possibleUrls = _generateFaviconUrls(normalizedUrl);
      
      outerLoop: for (final faviconUrl in possibleUrls) {
        try {
          // 使用http.Client以便可以控制下载过程
          final client = http.Client();
          final request = http.Request('GET', Uri.parse(faviconUrl));
          final response = await client.send(request)
              .timeout(const Duration(seconds: 5));
          
          // 检查响应状态码
          if (response.statusCode != 200) {
            client.close();
            continue;
          }
          
          // 检查内容类型是否为图片
          final contentType = response.headers['content-type'] ?? '';
          if (!contentType.contains('image/') && 
              !faviconUrl.endsWith('.ico') && 
              !faviconUrl.endsWith('.png') && 
              !faviconUrl.endsWith('.jpg') && 
              !faviconUrl.endsWith('.jpeg')) {
            client.close();
            continue;
          }
          
          // 检查文件大小
          final contentLength = response.contentLength ?? 0;
          if (contentLength > 100 * 1024) { // 限制为100KB
            client.close();
            continue;
          }
          
          // 读取数据(检查大小)
          final List<int> byteChunks = [];
          int totalBytes = 0;
          final maxSize = 100 * 1024; // 100KB

          await for (final chunk in response.stream) {
            byteChunks.addAll(chunk);
            totalBytes += chunk.length;
            // 如果已下载的数据超过限制，中断下载
            if (totalBytes > maxSize) {
              client.close();
              continue outerLoop;
            }
          }

          final bytes = Uint8List.fromList(byteChunks);
          if (bytes.isEmpty) {
            client.close();
            continue;
          }
          
          client.close();
          
          // 验证图像格式
          if (!_isValidImageFormat(bytes)) {
            continue;
          }

          // 将图标保存到缓存
          final image = await _saveToCache(encryptedIconId, bytes);
          
          final opIcon = OPIcon(
            iconId: iconId,
            image: image,
            fromCache: false,
          );
          _addToMemoryCache(iconId, opIcon);
          return opIcon;
        } catch (e) {
          // 继续尝试下一个URL
          continue;
        }
      }
      
      // 如果所有尝试都失败，返回默认图标
      return OPIcon();
    } catch (e) {
      // 出错时返回默认图标
      return OPIcon();
    }
  }

    // 获取缓存的图标（同步方法）
  OPIcon? getCachedIcon(String url) {
    try {
      final normalizedUrl = normalizeUrl(url);
      final iconId = _generateIconId(normalizedUrl);
      
      // 检查内存缓存
      if (_memoryCache.containsKey(iconId)) {
        return _memoryCache[iconId];
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // 验证图像格式
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return false;
    
    // 检查PNG格式 (89 50 4E 47)
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return true;
    }
    
    // 检查JPEG格式 (FF D8 FF)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    
    // 检查ICO格式 (00 00 01 00)
    if (bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01 && bytes[3] == 0x00) {
      return true;
    }
    
    // 检查GIF格式 ('GIF8')
    if (bytes.length >= 5 && 
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && 
        bytes[3] == 0x38 && (bytes[4] == 0x37 || bytes[4] == 0x39)) {
      return true;
    }
    
    // 检查BMP格式 ('BM')
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }
    
    // 检查WebP格式 ('RIFF' + 4字节 + 'WEBP')
    if (bytes.length >= 12 && 
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }
    
    return false;
  }

  // 添加到内存缓存
  void _addToMemoryCache(String iconId, OPIcon icon) {
    // 如果已经在缓存中，先移除旧的位置
    if (_memoryCache.containsKey(iconId)) {
      _memoryCacheKeys.remove(iconId);
    } 
    // 如果缓存已满，移除最久未使用的项
    else if (_memoryCacheKeys.length >= _maxMemoryCacheSize) {
      final oldestKey = _memoryCacheKeys.removeAt(0);
      _memoryCache.remove(oldestKey);
    }
    
    // 添加新项到缓存
    _memoryCache[iconId] = icon;
    _memoryCacheKeys.add(iconId);
  }
  
  // 规范化URL
  static String normalizeUrl(String url) {
    // 解析URL
    Uri uri = Uri.parse(url.toLowerCase());
    
    // 返回主域名部分
    return '${uri.scheme}://${uri.host}';
  }

  static bool canFetchIcon(String normalizedUrl){
    if (normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://')) {
      if (isFailedUrl(normalizedUrl)) {
        return false;
      }
      return true;
    }
    return false;
  }
  
  // 生成图标唯一ID
  String _generateIconId(String normalizedUrl) {
    // 提取主域名
    final uri = Uri.parse(normalizedUrl);
    final domain = uri.host;
    
    // 分割域名并获取主要部分
    final parts = domain.split('.');
    return parts.reversed.join('.');
  }
  
  // 生成可能的favicon URL列表
  List<String> _generateFaviconUrls(String normalizedUrl) {
    // final uri = Uri.parse(normalizedUrl);
    // final domain = uri.host;
    return [
      '$normalizedUrl/favicon.ico',
      '$normalizedUrl/favicon.png',
      // '$normalizedUrl/apple-touch-icon.png',
      // '$normalizedUrl/apple-touch-icon-precomposed.png',
      // // Google的favicon服务
      // 'https://www.google.com/s2/favicons?domain=$normalizedUrl&sz=64',
      // // 国内可用的图标服务
      // 'https://api.iowen.cn/favicon/$domain.png',
      // 'https://favicon.cccyun.cc/$domain',
      // 'https://statics.dnspod.cn/proxy_favicon/_/favicon?domain=$domain',
      // 'https://ico.kucat.cn/get.php?url=$domain',
    ];
  }
  
  // 从缓存获取图标
  Future<Image?> _getFromCache(String encryptedIconId) async {
    try {
      final file = await cacheManager.getFileFromCache(encryptedIconId);
      if (file != null) {
        final encryptedBytes = await file.file.readAsBytes();
        // 解密内容
        final decryptedBytes = _decryptContent(encryptedBytes);
        return Image.memory(decryptedBytes);
      }
    } catch (e) {
      // 缓存读取失败
    }
    return null;
  }
  
  // 保存图标到缓存
  Future<Image> _saveToCache(String encryptedIconId, Uint8List bytes) async {
    // 尝试解码图像，确保格式有效
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      await codec.getNextFrame();
      
      // 解码成功，创建图像
      final img = Image.memory(bytes);
      
      // 加密内容
      final encryptedBytes = _encryptContent(bytes);
      
      await cacheManager.putFile(
        encryptedIconId,
        encryptedBytes,
        key: encryptedIconId,
        maxAge: const Duration(days: 30),
      );
      
      return img;
    } catch (e) {
      // 图像解码失败，抛出异常
      throw Exception('无效的图像格式');
    }
  }
  
  // 清除缓存
  Future<void> clearCache() async {
    await cacheManager.emptyCache();
    _memoryCache.clear();
    _memoryCacheKeys.clear();
  }
}