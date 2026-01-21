import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../services/ux_service.dart';

/// App rating prompt dialog
class AppRatingDialog extends StatefulWidget {
  const AppRatingDialog({super.key});

  /// Show the rating dialog if conditions are met
  static Future<void> showIfNeeded(BuildContext context) async {
    if (await UxService.shouldShowRatingPrompt()) {
      await UxService.recordRatingPromptShown();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => const AppRatingDialog(),
        );
      }
    }
  }

  @override
  State<AppRatingDialog> createState() => _AppRatingDialogState();
}

class _AppRatingDialogState extends State<AppRatingDialog> {
  int _selectedRating = 0;

  void _selectRating(int rating) {
    setState(() => _selectedRating = rating);
    UxService.selectionHaptic();
  }

  Future<void> _submitRating() async {
    if (_selectedRating >= 4) {
      // Good rating - redirect to app store
      await _openAppStore();
    }
    await UxService.recordAppRated();
    if (mounted) {
      Navigator.of(context).pop();
      _showThankYouSnackbar();
    }
  }

  Future<void> _openAppStore() async {
    // TODO: Replace with actual app store URLs when published
    const androidUrl = 'https://play.google.com/store/apps/details?id=com.sparelink.app';
    const iosUrl = 'https://apps.apple.com/app/sparelink/id123456789';
    
    // Try Android first, then iOS
    final uri = Uri.parse(androidUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showThankYouSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.heart, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(_selectedRating >= 4 
                ? 'Thanks for your support!' 
                : 'Thanks for your feedback!'),
          ],
        ),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _maybeLater() async {
    Navigator.of(context).pop();
  }

  Future<void> _neverAskAgain() async {
    await UxService.recordAppRated();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 40,
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          const Text(
            'Enjoying SpareLink?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Your feedback helps us improve!',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isSelected = starNumber <= _selectedRating;
              return GestureDetector(
                onTap: () => _selectRating(starNumber),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isSelected ? LucideIcons.star : LucideIcons.star,
                    size: 40,
                    color: isSelected ? Colors.amber : Colors.grey[600],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          
          // Rating label
          Text(
            _getRatingLabel(),
            style: TextStyle(
              color: _selectedRating > 0 ? AppTheme.accentGreen : Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedRating > 0 ? _submitRating : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[800],
              ),
              child: Text(
                _selectedRating >= 4 ? 'Rate on App Store' : 'Submit Feedback',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Secondary actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _maybeLater,
                child: Text(
                  'Maybe Later',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
              Text(' • ', style: TextStyle(color: Colors.grey[700])),
              TextButton(
                onPressed: _neverAskAgain,
                child: Text(
                  'Don\'t Ask Again',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRatingLabel() {
    switch (_selectedRating) {
      case 1:
        return 'Poor 😞';
      case 2:
        return 'Fair 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Great! 😊';
      case 5:
        return 'Excellent! 🤩';
      default:
        return 'Tap to rate';
    }
  }
}
