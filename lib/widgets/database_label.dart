import 'package:flutter/material.dart';
import '../models/database_model.dart';

class DatabaseLabel extends StatelessWidget {
  final OPDatabase db;
  final double? iconSize;
  final Color? iconBackgroundColor;

  const DatabaseLabel({
    super.key,
    required this.db,
    this.iconSize = 16,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: iconBackgroundColor ?? Colors.grey[200],
          child: db.databaseIcon(size: iconSize),
        ),
        const SizedBox(width: 12),
        Text(db.name),
      ],
    );
  }
}
