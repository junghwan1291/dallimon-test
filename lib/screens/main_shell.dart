import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'home_screen.dart';
import 'dungeon_select_screen.dart';
import 'collection_screen.dart';
import 'quest_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    DungeonSelectScreen(),
    CollectionScreen(),
    QuestScreen(),
    _ShopPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.home_rounded,        label: '홈'),
      (icon: Icons.casino_rounded,      label: '던전'),
      (icon: Icons.pets_rounded,        label: '달리몬'),
      (icon: Icons.assignment_rounded,  label: '퀘스트'),
      (icon: Icons.storefront_rounded,  label: '상점'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBg,
        border: const Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item    = items[i];
              final active  = i == currentIndex;
              final color   = active ? AppColors.primary : AppColors.textHint;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: color, size: 22),
                      const SizedBox(height: 3),
                      Text(item.label,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ShopPlaceholder extends StatelessWidget {
  const _ShopPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛒', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('상점', style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('준비 중입니다', style: TextStyle(color: AppColors.textSub)),
          ],
        ),
      ),
    );
  }
}
