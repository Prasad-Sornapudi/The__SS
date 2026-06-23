import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? hintText;
  final bool isExpanded;
  final bool isRequired;
  final bool dropUp; // New parameter to control dropdown direction

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.isExpanded = true,
    this.isRequired = false,
    this.dropUp = false, // Default to dropping down
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  bool _isOpen = false;
  int _hoveredIndex = -1;
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      setState(() {
        _isOpen = false;
      });
    } else {
      _showDropdown();
      setState(() {
        _isOpen = true;
      });
    }
  }

  void _showDropdown() {
    final overlayState = Overlay.of(context);
    final renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // Create a temporary widget to measure the dropdown height
    final dropdownHeight = _calculateDropdownHeight();
    
    // Get screen dimensions for boundary checking
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate position based on dropUp parameter
    double dropdownTop;
    if (widget.dropUp) {
      // Position above the dropdown button, accounting for dropdown height
      dropdownTop = position.dy - dropdownHeight;
      
      // Ensure the dropdown doesn't go above the screen
      if (dropdownTop < 0) {
        dropdownTop = 0;
      }
    } else {
      // Position below the dropdown button
      dropdownTop = position.dy + size.height;
      
      // If there's not enough space below, switch to drop up
      if (dropdownTop + dropdownHeight > screenSize.height && widget.dropUp == false) {
        dropdownTop = position.dy - dropdownHeight;
        // Ensure it doesn't go above screen
        if (dropdownTop < 0) {
          dropdownTop = 0;
        }
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleDropdown,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: dropdownTop,
            width: size.width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.5),   // Dropdown Background colorconst Color.fromARGB(255, 134, 164, 196),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.glassBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isHovered = _hoveredIndex == index;
                    
                    return GestureDetector(
                      onTap: () {
                        _toggleDropdown();
                        if (widget.onChanged != null) {
                          widget.onChanged!(item.value);
                        }
                      },
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = -1),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), //text tab height
                            decoration: BoxDecoration(
                              color: isHovered 
                                ? AppTheme.primaryColor.withOpacity(0.3)
                                :  AppTheme.darkNavyBlue.withOpacity(0.90), // Dropdown tab option color
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isHovered 
                                  ? AppTheme.primaryColor.withOpacity(0.5)
                                  : AppTheme.glassBorder,
                                width: 1,
                              ),
                            ),
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              child: item.child ?? const Text(''),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlayState.insert(_overlayEntry!);
  }

  /// Calculate the approximate height of the dropdown menu
  double _calculateDropdownHeight() {
    // More accurate calculation based on actual item structure
    // Each item has:
    // - Outer container padding: 4 (top and bottom = 8)
    // - Inner container vertical padding: 12 (top and bottom = 24)
    // - Inner container top/bottom border: 1 (top and bottom = 2)
    // - Approximate text height: 16
    // - Spacing between items: 6 (approx)
    final itemHeight = 8.0 + 24.0 + 2.0 + 16.0 + 6.0;
    final totalHeight = widget.items.length * itemHeight + 20.0; // Add outer padding and margins
    
    // Ensure reasonable minimum and maximum heights
    // But don't exceed a reasonable portion of screen height
    return totalHeight.clamp(60.0, 300.0);
  }

  @override
  Widget build(BuildContext context) {
    // Find the selected item to display
    Widget selectedItemWidget = widget.hintText != null
        ? Text(widget.hintText!, style: const TextStyle(color: Colors.white70))
        : const Text('Select an option', style: TextStyle(color: Colors.white70));

    if (widget.value != null) {
      try {
        final selectedItem = widget.items.firstWhere(
          (item) => item.value == widget.value,
        );
        selectedItemWidget = selectedItem.child ?? selectedItemWidget;
      } catch (e) {
        // If no matching item found, keep the hint or default text
      }
    }

    return Container(
      key: _dropdownKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          width: widget.isExpanded ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: selectedItemWidget),
              Icon(
                _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}