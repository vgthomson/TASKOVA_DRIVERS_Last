
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:taskova_drivers/Model/Notifications/notification_service.dart';
import 'package:taskova_drivers/View/Community/community_page.dart';
import 'package:taskova_drivers/View/Homepage/homepage.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';
import 'package:taskova_drivers/View/Profile/profilepage.dart';


class MainWrapper extends StatefulWidget {
  const MainWrapper({Key? key}) : super(key: key);

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  int _currentIndex = 0;
  late AppLanguage appLanguage;

  // Navigator keys for each tab to manage their navigation stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // For HomePage
    GlobalKey<NavigatorState>(), // For CommunityPage
    GlobalKey<NavigatorState>(), // For ProfilePage
  ];

  final List<Widget> _pages = [
    const HomePage(),
    const CommunityPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    appLanguage = Provider.of<AppLanguage>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _notificationService.startNotificationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _notificationService.startNotificationService();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        break;
      default:
        break;
    }
  }

  // Handle tab tap and reset Home tab stack if Home is selected
  void _onTabTapped(int index) {
  if (_currentIndex == index && index == 0) {
    _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
  } else if (_currentIndex == index && index == 2) {
    // Optional: add behavior for 3rd tab
    _navigatorKeys[2].currentState?.popUntil((route) => route.isFirst);
  } else {
    setState(() {
      _currentIndex = index;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: CupertinoColors.systemBackground,
      child: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: CupertinoColors.systemBackground,
          activeColor: CupertinoColors.systemBlue,
          inactiveColor: CupertinoColors.systemGrey,
          items: [
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 0
                  ? CupertinoIcons.house_fill
                  : CupertinoIcons.house),
              label: appLanguage.get('Home') ?? 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 1
                  ? CupertinoIcons.person_2_fill
                  : CupertinoIcons.person_2),
              label: appLanguage.get('Community') ?? 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(_currentIndex == 2
                  ? CupertinoIcons.person_fill
                  : CupertinoIcons.person),
              label: appLanguage.get('Profile') ?? 'Profile',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(
            navigatorKey: _navigatorKeys[index],
            builder: (context) {
              return _pages[index];
            },
          );
        },
      ),
    );
  }
}