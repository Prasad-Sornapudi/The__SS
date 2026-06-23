import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../widgets/scanner_widgets.dart';
import '../widgets/web_qr_scanner.dart';

/// A unified scanner widget that handles:
/// 1. Platform detection (Mobile vs Web)
/// 2. Camera permissions
/// 3. Scanner initialization
/// 4. UI Overlay (Viewfinder)
/// 5. Manual Entry fallback
class UnifiedScannerWidget extends StatefulWidget {
  final ClassModel activeClass;
  final AttendanceProvider attendanceProvider;
  final Function(String code) onScan;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  final Function(ClassModel?)? onClassChanged;
  final bool isActive; // Logic to control camera start/stop

  const UnifiedScannerWidget({
    super.key,
    required this.activeClass,
    required this.attendanceProvider,
    required this.onScan,
    required this.onBack,
    required this.onSettings,
    this.onClassChanged,
    this.isActive = true, // Default to true
  });

  @override
  State<UnifiedScannerWidget> createState() => _UnifiedScannerWidgetState();
}

class _UnifiedScannerWidgetState extends State<UnifiedScannerWidget> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _permissionError;
  bool _isFlashOn = false;
  Offset? _tapPosition;
  double _zoomFactor = 0.0;

  void _handleTapToFocus(TapUpDetails details, BoxConstraints constraints) {
    if (_controller == null) return;

    final Offset localPosition = details.localPosition;
    final double relativeX = localPosition.dx / constraints.maxWidth;
    final double relativeY = localPosition.dy / constraints.maxHeight;

    try {
      // Set focus point logic if needed
    } catch (e) {
      print('Focus error: $e');
    }

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _controller!.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller!.stop();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void didUpdateWidget(UnifiedScannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller?.start();
      } else {
        _controller?.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    try {
      setState(() {
        _hasPermission = false;
        _permissionError = null;
        _isInitialized = false;
      });

      if (kIsWeb) {
        setState(() {
          _hasPermission = true;
          _isInitialized = true;
        });
        return;
      }
      
      final permission = await Permission.camera.request();
      
      if (permission.isGranted) {
        try {
          _controller = MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
            torchEnabled: false,
            formats: [BarcodeFormat.qrCode], // OPTIMIZATION: Scan only QR codes
          );

          setState(() {
            _hasPermission = true;
            _isInitialized = true;
          });
        } catch (e) {
          setState(() {
            _hasPermission = false;
            _permissionError = 'Camera initialization failed: $e';
          });
        }
      } else {
        setState(() {
          _hasPermission = false;
          _permissionError = 'Camera permission denied. Please enable camera access in your device settings and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _permissionError = 'Camera setup failed: $e\n\nPlease try:\n• Refreshing the page\n• Checking camera permissions\n• Using manual entry instead';
      });
    }
  }

  void _toggleFlash() {
    if (_controller != null) {
      _controller!.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    }
  }

  void _switchCamera() {
    if (_controller != null) {
      _controller!.switchCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permissions (skip for web since we use manual entry)
    if (!kIsWeb && !_hasPermission) {
      return PermissionErrorWidget(
        error: _permissionError,
        onRetry: _initializeScanner,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      child: Column(
        children: [
          // AppBar with back button
          AppBar(
            title: const Text('QR Scanner'),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            actions: [
              if (!kIsWeb && _isInitialized && _hasPermission) ...[
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                ),
                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: widget.onSettings,
              ),
            ],
          ),
          
          // Class Header
          ClassSelectionHeader(
            activeClass: widget.activeClass,
            onClassChanged: widget.onClassChanged ?? (_) {},
          ),

          // Scanner View
          Expanded(
            child: kIsWeb
                ? WebQRScanner(
                      onScan: widget.onScan,
                      overlayMessage: 'Position QR code within the viewfinder',
                    )
                : Stack(
                    children: [
                      if (_isInitialized) ...[
                        // Camera Preview with Tap to Focus
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              onTapUp: (details) => _handleTapToFocus(details, constraints),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: (capture) {
                                      final List<Barcode> barcodes = capture.barcodes;
                                      for (final barcode in barcodes) {
                                        if (barcode.rawValue != null) {
                                          widget.onScan(barcode.rawValue!);
                                          break;
                                        }
                                      }
                                    },
                                  ),
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
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Scanner Overlay
                        const ScannerOverlay(),

                        // Zoom Slider (Native) - Placed after overlay to ensure it receives touches
                        if (_isInitialized)
                          Positioned(
                            right: 16,
                            top: 100,
                            bottom: 100,
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Slider(
                                    value: _zoomFactor,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: AppTheme.primaryColor,
                                    inactiveColor: Colors.white24,
                                    onChanged: (value) {
                                      setState(() {
                                        _zoomFactor = value;
                                        _controller?.setZoomScale(value);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Manual Entry Button
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: SafeArea(
                            child: ManualEntryButton(
                              onManualEntry: widget.onScan,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
