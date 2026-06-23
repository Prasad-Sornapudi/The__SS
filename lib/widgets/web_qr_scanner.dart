import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import '../constants/theme.dart'; // Import AppTheme

class WebQRScanner extends StatefulWidget {
  final Function(String) onScan;
  final String? overlayMessage;

  const WebQRScanner({
    Key? key,
    required this.onScan,
    this.overlayMessage,
  }) : super(key: key);

  @override
  State<WebQRScanner> createState() => _WebQRScannerState();
}

class _WebQRScannerState extends State<WebQRScanner> {
  final TextEditingController _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back, // Default to environment/back camera
    formats: [BarcodeFormat.qrCode], // OPTIMIZATION: Scan only QR codes
  );
  bool _isManualEntryExpanded = false;
  double _zoomFactor = 0.0;

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Offset? _tapPosition;

  void _handleTapToFocus(TapUpDetails details, BoxConstraints constraints) {
    // Controller is final and cannot be null
    
    final Offset localPosition = details.localPosition;
    
    // Visual feedback
    setState(() {
      _tapPosition = localPosition;
    });

    // Hide indicator after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _tapPosition = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner Area
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) => _handleTapToFocus(details, constraints),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              widget.onScan(barcode.rawValue!);
                            }
                          }
                        },
                      ),
                      // Visual Focus Indicator
                      if (_tapPosition != null)
                        Positioned(
                          left: _tapPosition!.dx - 20,
                          top: _tapPosition!.dy - 20,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                          ),
                        ),
                // Overlay Message
                if (widget.overlayMessage != null)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.overlayMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Scanner Overlay Box (Visual Guide)
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                // Camera Switch Button
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                      onPressed: () => _scannerController.switchCamera(),
                      tooltip: 'Switch Camera',
                    ),
                  ),
                ),

                // Zoom Slider
                Positioned(
                  right: 20,
                  top: 80,
                  bottom: 80,
                  child: RotatedBox(
                    quarterTurns: 3, // Vertical orientation
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_out, color: Colors.white70, size: 16),
                          Slider(
                            value: _zoomFactor,
                            min: 0.0,
                            max: 1.0,
                            activeColor: AppTheme.primaryColor,
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              setState(() {
                                _zoomFactor = value;
                                _scannerController.setZoomScale(value);
                              });
                            },
                          ),
                          const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ),

        // Manual Entry Section (Collapsible or always visible based on need)
        Container(
          padding: const EdgeInsets.all(AppTheme.mediumSpacing),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isManualEntryExpanded = !_isManualEntryExpanded;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manual Entry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(
                      _isManualEntryExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              if (_isManualEntryExpanded) ...[
                const SizedBox(height: 16),
                _buildManualEntryForm(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _manualController,
          decoration: InputDecoration(
            hintText: 'Enter QR data',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.qr_code),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _pasteFromClipboard,
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onScan(value);
              _manualController.clear();
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GradientButton(
              onPressed: () {
                final value = _manualController.text.trim();
                if (value.isNotEmpty) {
                  widget.onScan(value);
                  _manualController.clear();
                }
              },
              child: const Text('Submit', style: TextStyle(color: AppTheme.buttonTextColor)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        _manualController.text = clipboardData!.text!;
      }
    } catch (e) {
      // Handle clipboard error
    }
  }
}