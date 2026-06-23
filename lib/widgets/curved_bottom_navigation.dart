import 'package:flutter/material.dart';
import 'package:molten_navigationbar_flutter/molten_navigationbar_flutter.dart';
import '../constants/theme.dart';

class CurvedBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CurvedBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: const BoxDecoration(
        // Make the surrounding area transparent
        color: Colors.transparent,
      ),
      child: MoltenBottomNavigationBar(
        selectedIndex: selectedIndex,
        onTabChange: onItemTapped,
        barHeight: 80.0,
        barColor: const Color(0xFF082865), // Navigation bar color 0xB308365A
        domeCircleColor: const Color(0xFFFDD64E),
        domeHeight: 20.0,
        domeCircleSize: 50.0,
        borderRaduis: BorderRadius.circular(16),
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: 300),
        tabs: [
          MoltenTab(
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selectedIndex == 0 ? AppTheme.buttonGradient : null,
                color: selectedIndex == 0 ? null : Colors.transparent,
              ),
              child: Icon(
                Icons.home, 
                color: selectedIndex == 0 ? const Color(0xFF0A2346) : const Color.fromARGB(255, 134, 164, 196), 
                size: 35,
              ),
            ),
            title: Transform.translate(
              offset: const Offset(0, -10), // Move up by 10 pixels
              child: Text(
                'Home',
                style: TextStyle(
                  color: selectedIndex == 0 ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            selectedColor: const Color.fromARGB(0, 10, 21, 39),
            unselectedColor: Colors.white,
          ),
          MoltenTab(
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selectedIndex == 1 ? AppTheme.buttonGradient : null,
                color: selectedIndex == 1 ? null : Colors.transparent,
              ),
              child: Icon(
                Icons.dashboard, 
                color: selectedIndex == 1 ? const Color(0xFF0A2346) : const Color.fromARGB(255, 134, 164, 196), 
                size: 35,
              ),
            ),
            title: Transform.translate(
              offset: const Offset(0, -10), // Move up by 10 pixels
              child: Text(
                'Dashboard',
                style: TextStyle(
                  color: selectedIndex == 1 ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            selectedColor: AppTheme.darkNavyBlue,
            unselectedColor: Colors.white,
          ),
          MoltenTab(
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selectedIndex == 2 ? AppTheme.buttonGradient : null,
                color: selectedIndex == 2 ? null : Colors.transparent,
              ),
              child: Icon(
                Icons.settings, 
                color: selectedIndex == 2 ? const Color(0xFF0A2346) : const Color.fromARGB(255, 134, 164, 196), 
                size: 35,
              ),
            ),
            title: Transform.translate(
              offset: const Offset(0, -10), // Move up by 10 pixels
              child: Text(
                'Settings',
                style: TextStyle(
                  color: selectedIndex == 2 ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            selectedColor: AppTheme.darkNavyBlue,
            unselectedColor: Colors.white,
          ),
        ],
      ),
    );
  }
}