import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../models/database_model.dart';
import '../widgets/icon_widget.dart';
import '../utils/navigation_helper.dart';

class EntryListTile extends StatelessWidget {
  final KdbxEntry item;
  final Function()? onChanged;
  final Function(KdbxItem)? onTap;
  final bool isMobileLayout;

  const EntryListTile({
    super.key,
    required this.item,
    this.isMobileLayout = true,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: KdbxIconWidget(entry:item, size:40),
      title: Text(item.name),
      subtitle: Text(
        item.getUsername(),
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: isMobileLayout?const Icon(Icons.chevron_right):null,
      onTap: () async {
        if (onTap != null) {
          onTap?.call(item);
        } else {
          NavigationHelper.navigateToDetail(
            context, 
            item,
            onChanged: (_) => onChanged?.call(),
          );
        }
      },
    );
  }
}
