import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

/// Camera Screen - Full Implementation
/// Features: Camera preview, flash, zoom, multi-capture (4 max), gallery picker
class CameraScreenFull extends ConsumerStatefulWidget {
  final bool isPartPhoto;
  
  const CameraScreenFull({super.key, this.isPartPhoto = false});

  @override
  ConsumerState<CameraScreenFull> createState() => _CameraScreenFullState();
}

class _CameraScreenFullState extends ConsumerState<CameraScreenFull> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  List<XFile> _capturedImages = [];
  
  bool _isInitialized = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  
  // Image pending confirmation (for part photos)
  XFile? _pendingPartImage;
  Uint8List? _pendingImageBytes;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
  
  /// Initialize camera with permissions
  Future<void> _initializeCamera() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    
    if (!cameraStatus.isGranted) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }
    
    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found')),
          );
        }
        return;
      }
      
      // Initialize with back camera
      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      // Get zoom levels with error handling for web compatibility
      try {
        _maxZoom = await _cameraController!.getMaxZoomLevel();
        _minZoom = await _cameraController!.getMinZoomLevel();
      } catch (e) {
        // Zoom not supported (common on web browsers)
        _maxZoom = 1.0;
        _minZoom = 1.0;
        _currentZoom = 1.0;
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }
  
  /// Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Camera Permission Required'),
        content: const Text(
          'SpareLink needs camera access to capture part photos. Please enable camera permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              context.pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Toggle flash
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }
  
  /// Toggle front/back camera
  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });
    
    await _cameraController?.dispose();
    
    final camera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == 
        (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
    );
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    await _cameraController!.initialize();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }
  
  /// Set zoom level with error handling for web compatibility
  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null) return;
    
    // Check if zoom is supported
    if (_maxZoom <= 1.0 && _minZoom >= 1.0) {
      // Zoom not supported on this device/browser
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zoom is not supported on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    try {
      final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
      await _cameraController!.setZoomLevel(clampedZoom);
      
      if (mounted) {
        setState(() {
          _currentZoom = clampedZoom;
        });
      }
    } catch (e) {
      // Silently fail if zoom is not supported
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zoom is not supported on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// Capture photo
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    // For part photos, only allow 1 image
    final maxImages = widget.isPartPhoto ? 1 : 4;
    
    if (_capturedImages.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $maxImages image${maxImages > 1 ? 's' : ''} allowed')),
      );
      return;
    }
    
    try {
      final image = await _cameraController!.takePicture();
      
      if (mounted) {
        // For part photos, show preview for confirmation instead of auto-uploading
        if (widget.isPartPhoto) {
          final bytes = await image.readAsBytes();
          setState(() {
            _pendingPartImage = image;
            _pendingImageBytes = bytes;
          });
        } else {
          setState(() {
            _capturedImages.add(image);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }
  
  /// Upload part photo and return URL
  Future<void> _uploadAndReturnPartPhoto(XFile image) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGreen),
        ),
      );
      
      // Read image bytes
      final bytes = await image.readAsBytes();
      final fileName = 'part_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      await supabase.storage.from('part-images').uploadBinary(
        'requests/$fileName',
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      
      // Get public URL
      final publicUrl = supabase.storage.from('part-images').getPublicUrl('requests/$fileName');
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        context.pop(publicUrl); // Return URL to previous screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }
  
  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    // For part photos, only allow 1 image
    final maxImages = widget.isPartPhoto ? 1 : 4;
    
    if (_capturedImages.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $maxImages image${maxImages > 1 ? 's' : ''} allowed')),
      );
      return;
    }
    
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (image != null && mounted) {
        // For part photos, show preview for confirmation instead of auto-uploading
        if (widget.isPartPhoto) {
          final bytes = await image.readAsBytes();
          setState(() {
            _pendingPartImage = image;
            _pendingImageBytes = bytes;
          });
        } else {
          setState(() {
            _capturedImages.add(image);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }
  
  /// Delete captured image
  void _deleteImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }
  
  /// Confirm the pending part photo and proceed with upload
  void _confirmPartPhoto() {
    if (_pendingPartImage != null) {
      _uploadAndReturnPartPhoto(_pendingPartImage!);
    }
  }
  
  /// Reject the pending part photo and return to camera
  void _rejectPartPhoto() {
    setState(() {
      _pendingPartImage = null;
      _pendingImageBytes = null;
    });
  }
  
  /// Proceed to vehicle form
  void _proceedToForm() {
    if (_capturedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture at least one photo')),
      );
      return;
    }
    
    // TODO: Navigate to vehicle form with images
    context.push('/vehicle-form', extra: _capturedImages);
  }
  
  /// Build image confirmation overlay for part photos
  Widget _buildImageConfirmationOverlay() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen image preview
          Positioned.fill(
            child: _pendingImageBytes != null
                ? Image.memory(
                    _pendingImageBytes!,
                    fit: BoxFit.contain,
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentGreen),
                  ),
          ),
          
          // Top bar with title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Review Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom controls - Reject (X) and Confirm (✓) buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button (X) - Retake
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _rejectPartPhoto,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withOpacity(0.2),
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Retake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // Confirm button (✓) - Use Photo
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _confirmPartPhoto,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentGreen.withOpacity(0.2),
                              border: Border.all(color: AppTheme.accentGreen, width: 3),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppTheme.accentGreen,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Show image confirmation overlay for part photos
    if (_pendingPartImage != null && _pendingImageBytes != null) {
      return _buildImageConfirmationOverlay();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accentGreen),
            ),
          
          // Top Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    
                    // Title
                    Text(
                      widget.isPartPhoto 
                          ? 'Take Part Photo'
                          : 'Take Photos (${_capturedImages.length}/4)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    // Flash Toggle
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: _isFlashOn ? Colors.yellow : Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Zoom Controls - Only show if zoom is supported
          if (_isInitialized && _maxZoom > 1.0)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.3,
              child: Column(
                children: [
                  _ZoomButton(
                    label: '1x',
                    isActive: _currentZoom < 1.5,
                    onTap: () => _setZoom(1.0),
                  ),
                  const SizedBox(height: 12),
                  if (_maxZoom >= 2.0)
                    _ZoomButton(
                      label: '2x',
                      isActive: _currentZoom >= 1.5 && _currentZoom < 2.5,
                      onTap: () => _setZoom(2.0),
                    ),
                  if (_maxZoom >= 2.0) const SizedBox(height: 12),
                  if (_maxZoom >= 3.0)
                    _ZoomButton(
                      label: '3x',
                      isActive: _currentZoom >= 2.5,
                      onTap: () => _setZoom(3.0),
                    ),
                ],
              ),
            ),
          
          // Image Preview Grid
          if (_capturedImages.isNotEmpty)
            Positioned(
              left: 16,
              top: 100,
              child: Container(
                width: 80,
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _capturedImages.length,
                  itemBuilder: (context, index) {
                    return _ImagePreviewTile(
                      image: _capturedImages[index],
                      onDelete: () => _deleteImage(index),
                    );
                  },
                ),
              ),
            ),
          
          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Picker
                    _ControlButton(
                      icon: Icons.photo_library,
                      onTap: _pickFromGallery,
                    ),
                    
                    // Capture Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _capturedImages.length >= 4
                              ? Colors.grey
                              : Colors.white.withOpacity(0.3),
                        ),
                        child: _capturedImages.length >= 4
                            ? const Icon(Icons.check, color: Colors.white, size: 32)
                            : null,
                      ),
                    ),
                    
                    // Rotate Camera
                    _ControlButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _toggleCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Next Button (when images captured)
          if (_capturedImages.isNotEmpty)
            Positioned(
              right: 24,
              bottom: 100,
              child: FloatingActionButton.extended(
                onPressed: _proceedToForm,
                backgroundColor: AppTheme.accentGreen,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
            ),
        ],
      ),
    );
  }
}

// Zoom Button Widget
class _ZoomButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  
  const _ZoomButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
              ? AppTheme.accentGreen 
              : Colors.white.withOpacity(0.3),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Control Button Widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  
  const _ControlButton({
    required this.icon,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.3),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

// Image Preview Tile - Web compatible using Image.memory
class _ImagePreviewTile extends StatefulWidget {
  final XFile image;
  final VoidCallback onDelete;
  
  const _ImagePreviewTile({
    required this.image,
    required this.onDelete,
  });

  @override
  State<_ImagePreviewTile> createState() => _ImagePreviewTileState();
}

class _ImagePreviewTileState extends State<_ImagePreviewTile> {
  Uint8List? _imageBytes;
  
  @override
  void initState() {
    super.initState();
    _loadImageBytes();
  }
  
  Future<void> _loadImageBytes() async {
    final bytes = await widget.image.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
