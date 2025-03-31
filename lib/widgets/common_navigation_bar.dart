import 'package:flutter/material.dart';

class CommonNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CommonNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static Widget buildAppBarTitle() {
    return const Text('OpenPass');
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.lock),
          label: '保险库',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    );
  }
}