import 'package:flutter/material.dart';
import 'package:shiori/domain/assets.dart';
import 'package:shiori/domain/enums/enums.dart';
import 'package:shiori/presentation/shared/extensions/element_type_extensions.dart';

class ElementImage extends StatelessWidget {
  final ElementType type;
  final String path;
  final bool useDarkForBackgroundColor;
  final double radius;

  ElementImage.fromType({
    Key? key,
    required this.type,
    this.useDarkForBackgroundColor = false,
    this.radius = 25,
  })  : path = type.getElementAssetPath(),
        super(key: key);

  ElementImage.fromPath({
    Key? key,
    required this.path,
    this.useDarkForBackgroundColor = false,
    this.radius = 25,
  })  : type = Assets.getElementTypeFromPath(path),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = useDarkForBackgroundColor ? Colors.black.withAlpha(100) : type.getElementColorFromContext(context);
    return Container(
      margin: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: AssetImage(Assets.getElementPathFromType(type)),
      ),
    );
  }
}
