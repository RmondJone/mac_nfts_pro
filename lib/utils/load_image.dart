import 'package:flutter/material.dart';

/// 注释：加载本地 asset 图片组件
/// 时间：2026/08/16 19:40
/// 作者：RmondJone
class LoadAssetImage extends StatelessWidget {
  final String image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final String format;

  const LoadAssetImage(
    this.image, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.format = 'png',
  });

  @override
  Widget build(BuildContext context) {
    final path = image.startsWith('assets/')
        ? image
        : 'assets/images/$image.$format';

    return Image.asset(
      path,
      height: height,
      width: width,
      fit: fit,
      color: color,
    );
  }
}

/// 注释：通用图片加载组件 (支持本地/网络)
/// 时间：2026/08/16 19:40
/// 作者：RmondJone
class LoadImage extends StatelessWidget {
  final String image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final Widget? placeholder;

  const LoadImage(
    this.image, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(
        image,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (context, error, stackTrace) =>
            placeholder ?? SizedBox(width: width, height: height),
      );
    }
    return LoadAssetImage(
      image,
      width: width,
      height: height,
      fit: fit,
      color: color,
    );
  }
}
