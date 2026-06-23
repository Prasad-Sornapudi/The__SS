import 'package:flutter/material.dart';
import '../constants/theme.dart';

class CustomBottomNavigation extends StatelessWidget {
  const CustomBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        // Set the background to fully transparent
        color: Colors.transparent,
      ),
      child: Padding(
        // Add padding for the "floating" items
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.qr_code_scanner, 'Scanner', false),
            _buildNavItem(Icons.dashboard, 'Dashboard', true),
            _buildNavItem(Icons.settings, 'Settings', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    // Wrapped with Expanded to ensure equal width distribution
    return Expanded(
      child: Container(
        // Spacing between buttons
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          // Filled background for the individual item
          color: isActive ? Colors.pink.shade700 : Colors.pink.shade500,
          // Rounded corners on the individual item
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              // Icon color set to white for contrast on the pink background
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                // Text color set to white for contrast on the pink background
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}