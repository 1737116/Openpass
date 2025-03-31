import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kpasslib/kpasslib.dart';
import '../providers/providers.dart';
import 'base_page.dart';
import '../widgets/add_entry_button.dart';
import '../widgets/common_search_bar.dart';
import '../widgets/icon_widget.dart';
import '../models/database_model.dart';
import '../services/item_list_service.dart';
import '../utils/navigation_helper.dart';
import '../widgets/vault_icon_widget.dart';
// 分组类型
enum HomePageGroupType {
  favorite,
  recentSearch,
  recentCreated,
}

class HomePage extends BasePage {
  const HomePage({super.key, required super.onSwitchPage});

  @override
  BasePageState<HomePage> createState() => _HomePageState();
}

//class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
class _HomePageState extends BasePageState<HomePage> with TickerProviderStateMixin {
  List<KdbxEntry> _favoriteItems = [];
  List<KdbxEntry> _recentItems = [];
  List<KdbxEntry> _recentCreated = [];
  final Map<HomePageGroupType, bool> _expandedStates = {};
  final Map<String, AnimationController> _copyAnimationControllers = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
    _expandedStates[HomePageGroupType.favorite] = true;
    _expandedStates[HomePageGroupType.recentSearch] = true;
    _expandedStates[HomePageGroupType.recentCreated] = true;
  }

  @override
  void dispose() {
    for (var controller in _copyAnimationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    final itemListService = ref.read(itemListServiceProvider);
    setState(() {
      _favoriteItems = itemListService.getFavoriteItems();
      _recentItems = itemListService.getRecentSearchItems();
      _recentCreated = itemListService.getRecentCreatedItems();
    });
  }

  @override
  Widget buildTitle() {
    final localStorageService = ref.read(localStorageServiceProvider);
    String appIcon = localStorageService.getAppIcon();
    return Row(
      children: [
        // Icon(Icons.watch, size: 30),
        VaultIconWidget(iconName:appIcon, size: 20),
        SizedBox(width: 8),
        Text('首页'),
      ],
    );
  }
  
  @override
  List<Widget> buildActions() {
    return [
      AddEntryButton(onEntryAdded: () {
        // 刷新数据
        _loadItems();
      }),
    ];
  }
  
  @override
  bool showBackButton() => false;
  
  Widget _buildGroupHeader(HomePageGroupType gt, IconData icon, String title,
      List<KdbxEntry> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedStates[gt] = !(_expandedStates[gt] ?? false);
                });
              },
              child: ListTile(
                  leading: Icon(icon, color: Colors.amber),
                  title: Text(title),
                  trailing: AnimatedRotation(
                    turns: _expandedStates[gt] ?? false ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey),
                  )),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Column(
                children: [
                  const Divider(height: 1),
                  if (items.isEmpty)
                    const ListTile(
                      title: Text(
                        '暂无内容',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: KdbxIconWidget(entry: item, size: 40),
                          title: Text(item.name),
                          subtitle: Text(
                            item.getUsername(),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            NavigationHelper.navigateToDetail(
                              context, 
                              item,
                              onChanged: (newItem) async {
                                await _loadItems(); // 更新后重新加载数据
                              },
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
              crossFadeState: _expandedStates[gt] ?? false
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final itemListService = ref.read(itemListServiceProvider);
    // 获取快速访问的项目列表
    List<QuickAccessEntry> quickAccessItems = itemListService.getQuickAccessItems();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: quickAccessItems.map((item) {
          var entry = item.entry;
          String quickAccessKey = item.fieldName;
          var quickAccessVal = entry.getValue(quickAccessKey);

          // 为每个卡片创建动画控制器
          final String cardKey = '${entry.id}_${item.fieldName}';
          _copyAnimationControllers[cardKey] ??= AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 500),
          );

          return AnimatedBuilder(
            animation: _copyAnimationControllers[cardKey]!,
            builder: (context, child) {
              final bool isAnimating =
                  _copyAnimationControllers[cardKey]!.value > 0;
              return Card(
                elevation: 2,
                color: Color.lerp(
                  Colors.white,
                  Colors.blue,
                  _copyAnimationControllers[cardKey]!.value,
                ),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: InkWell(
                    onTap: () async {
                      if (quickAccessVal != null) {
                        Clipboard.setData(
                            ClipboardData(text: quickAccessVal.text));
                      }
                      _copyAnimationControllers[cardKey]!.forward().then((_) {
                        _copyAnimationControllers[cardKey]!.reverse();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KdbxIconWidget(entry:entry, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  entry.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            quickAccessKey,
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (quickAccessVal != null)
                            Text(
                              isAnimating
                                  ? '已复制'
                                  : (quickAccessVal is ProtectedTextField
                                      ? '••••••••'
                                      : (quickAccessVal.text.length < 20
                                          ? quickAccessVal.text
                                          : "${quickAccessVal.text.substring(0, 20)}...")),
                              style: TextStyle(
                                color: isAnimating ? Colors.white : Colors.grey,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: const CommonSearchBar(),
        ),
        Expanded(
          child: ListView(
            children: [
              _buildQuickAccessGrid(),
              _buildGroupHeader(HomePageGroupType.favorite, Icons.star_border,
                  '收藏夹', _favoriteItems),
              _buildGroupHeader(HomePageGroupType.recentSearch, Icons.history,
                  '最近搜索', _recentItems),
              _buildGroupHeader(HomePageGroupType.recentCreated,
                  Icons.access_time, '最近创建', _recentCreated),
            ],
          ),
        ),
      ],
    );
  }
}
