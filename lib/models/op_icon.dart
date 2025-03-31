import 'package:flutter/material.dart';

class OPIcon {
  final IconData? iconData; // 字符图标
  final Image? image;  // 图片数据
  final String? iconId;
  final bool fromCache;

  const OPIcon({
    this.iconData,
    this.image,
    this.iconId,
    this.fromCache = false,
  });

}
