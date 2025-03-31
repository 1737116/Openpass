import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../utils/navigation_helper.dart';

class AddEntryButton extends ConsumerWidget {
  final OPDatabase? database;
  final Function()? onEntryAdded;

  const AddEntryButton({
    super.key,
    this.database,
    this.onEntryAdded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.add, color: Colors.blue),
      onPressed: () {
        final itemListService = ref.read(itemListServiceProvider);
        final parentFolder = itemListService.opRoot.getDefaultAddEntryFolder();
        if (parentFolder != null) {
          NavigationHelper.navigateToDetailEdit(context, parentFolder, null,
            onChanged: (isSaved) async {
              if (isSaved && onEntryAdded != null) {
                onEntryAdded!();
              }
            }
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('尚未打开任何数据库，无法新建条目')),
          );
        }
      },
    );
  }
}
