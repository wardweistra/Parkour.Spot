import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/spot_service.dart';
import '../services/deep_link_service.dart';
import 'spots/spots_list_screen.dart';
import 'spots/add_spot_screen.dart';
import 'spots/map_screen.dart';
import 'profile/profile_screen.dart';
import 'spots/spot_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  DeepLinkService? _deepLinkService;

  final List<Widget> _screens = [
    const SpotsListScreen(),
    const MapScreen(),
    const AddSpotScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // Load spots when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SpotService>(context, listen: false).fetchSpots();
      _deepLinkService = Provider.of<DeepLinkService>(context, listen: false);
      _handlePendingDeepLink();
      _deepLinkService?.addListener(_handlePendingDeepLink);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deepLinkService?.removeListener(_handlePendingDeepLink);
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handlePendingDeepLink() async {
    final deepLinkService = _deepLinkService;
    if (deepLinkService == null) return;

    final spotId = deepLinkService.consumePendingSpotId();
    if (spotId == null || !mounted) return;

    final spotService = Provider.of<SpotService>(context, listen: false);
    final spot = await spotService.fetchSpotById(spotId);
    if (!mounted) return;

    if (spot != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpotDetailScreen(spot: spot),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spot not found or unavailable.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Spots',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location),
            label: 'Add Spot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
