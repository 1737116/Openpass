import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/database_model.dart';
import '../widgets/entry_list_tile.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<KdbxEntry> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final itemListService = ref.read(itemListServiceProvider);
    final keyword = _searchController.text;
    List<KdbxEntry> result;
    if (keyword.isEmpty) {
      result = itemListService.getRecentSearchItems();
    } else {
      final allEntries = itemListService.opRoot.getEntriesAll();
      result = allEntries.where((entry) {
        // 搜索标题
        if (entry.name.toLowerCase().contains(keyword.toLowerCase())) {
          return true;
        }
        // 搜索其他字段
        for (var field in entry.fields.keys) {
          var val = entry.fields[field];
          if (val == null || val is ProtectedTextField) {
            continue;
          }
          if (val.text.toLowerCase().contains(keyword.toLowerCase())) {
            return true;
          }
        }
        return false;
      }).toList();
    }
    setState(() {
      _searchResults = result;
    });
  }

  void _onSelectedItem(KdbxItem entry) {
    if (entry is KdbxEntry){
      final itemDetailService = ref.read(itemDetailServiceProvider);
      itemDetailService.setSelectedEntry(entry, true);
    }
    Navigator.pop(context, entry);
  }

  void _onClose() {
    Navigator.pop(context);
  }

  Widget _buildListView() {
    final itemListService = ref.read(itemListServiceProvider);
    final layoutService = ref.watch(layoutServiceProvider);
    bool isMobileLayout = layoutService.isMobileLayout;
    List<Widget> children = [];
    bool isKeywordEmpty = _searchController.text.isEmpty;
    if (isKeywordEmpty) {
      children.add(ListTile(
        title: const Text('近期'),
        trailing: TextButton(
          onPressed: () {
            itemListService.clearRecentSearch();
            _onSearchChanged();
          },
          child: const Text('清除'),
        ),
      ));
    }

    if (_searchResults.isEmpty) {
      children.add(const Center(
        child: Text('没有找到相关结果'),
      ));
    }else{
      int idx = 0;
      for (var entry in _searchResults) {
        if (idx > 0) {
          children.add(const Padding(
            padding: EdgeInsets.only(left: 60.0, right: 25.0),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ));
        }
        children.add(EntryListTile(
          item: entry,
          onTap: isMobileLayout?null:_onSelectedItem,
          onChanged: _onSearchChanged,
        ));
        ++idx;
      }
    }

    return ListView(
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前主题的颜色
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // 根据主题选择适当的背景色
    final backgroundColor = isDarkMode 
        ? theme.colorScheme.surfaceVariant.withAlpha(75)
        : theme.colorScheme.surfaceVariant.withAlpha(25);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Focus(
              onKeyEvent: (focusNode, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                  _onClose();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SearchBar(
                controller: _searchController,
                hintText: '在全部项目中搜索',
                hintStyle: MaterialStatePropertyAll(
                  TextStyle(
                    fontSize: 13.0,
                    color: isDarkMode 
                        ? Colors.grey.withAlpha(150) 
                        : Colors.grey.withAlpha(125),
                  ),
                ),
                leading: const Icon(Icons.search),
                trailing: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _onClose,
                  ),
                ],
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(backgroundColor),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(
                      color: isDarkMode 
                          ? Colors.grey.withAlpha(75) 
                          : Colors.grey.withAlpha(50),
                      width: 0.5,
                    ),
                  ),
                ),
                autoFocus: true,
              ),
            ),
          ),
        ),
        titleSpacing: 0,
      ),
      body: _buildListView(),
    );
  }
}
