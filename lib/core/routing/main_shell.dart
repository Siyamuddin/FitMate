import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:fitmate/core/theme/app_colors.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Column(
      children: <Widget>[
        Expanded(child: navigationShell),
        CupertinoTabBar(
          currentIndex: navigationShell.currentIndex,
          backgroundColor: AppColors.surface(brightness).withValues(alpha: 0.92),
          onTap: (int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.flame), label: 'Workout'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.leaf_arrow_circlepath), label: 'Nutrition'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.chat_bubble_text), label: 'Coach'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Progress'),
          ],
        ),
      ],
    );
  }
}
