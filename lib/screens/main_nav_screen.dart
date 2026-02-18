import 'package:flutter/material.dart';
import 'explorer_search_screen.dart';
import 'next_step_screen.dart';

class MainNavScreen extends StatefulWidget {
  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigatorState = _navigatorKeys[_currentIndex].currentState;
        if (navigatorState != null && navigatorState.canPop()) {
          navigatorState.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            Navigator(
              key: _navigatorKeys[0],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => ExplorerSearchScreen(),
              ),
            ),
            Navigator(
              key: _navigatorKeys[1],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => NextStepScreen(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) {
              _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up),
              label: 'Next Step',
            ),
          ],
        ),
      ),
    );
  }
}
