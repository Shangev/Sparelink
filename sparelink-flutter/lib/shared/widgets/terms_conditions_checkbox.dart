import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/environment_config.dart';

/// Terms and Conditions Checkbox Widget
/// 
/// A reusable checkbox widget that displays terms & conditions and
/// privacy policy links. Required for legal compliance.
class TermsConditionsCheckbox extends StatelessWidget {
  final bool isChecked;
  final ValueChanged<bool?> onChanged;
  final String? errorText;
  
  const TermsConditionsCheckbox({
    super.key,
    required this.isChecked,
    required this.onChanged,
    this.errorText,
  });
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // URLs for legal documents
    final termsUrl = EnvironmentConfig.isProduction
        ? 'https://sparelink.co.za/terms'
        : 'https://sparelink.co.za/terms'; // Same for dev for now
    final privacyUrl = EnvironmentConfig.isProduction
        ? 'https://sparelink.co.za/privacy'
        : 'https://sparelink.co.za/privacy';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                onChanged: onChanged,
                activeColor: AppTheme.accentGreen,
                side: BorderSide(
                  color: errorText != null ? Colors.red : AppTheme.lightGray,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!isChecked),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppTheme.lightGray,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showTermsDialog(context, termsUrl),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showPrivacyDialog(context, privacyUrl),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  void _showTermsDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SpareLink Terms of Service',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Last updated: January 17, 2026\n\n'
                '1. ACCEPTANCE OF TERMS\n'
                'By accessing or using SpareLink, you agree to be bound by these Terms and Conditions.\n\n'
                '2. SERVICE DESCRIPTION\n'
                'SpareLink is a marketplace platform connecting mechanics with auto parts suppliers. We facilitate the connection but are not responsible for the quality or delivery of parts.\n\n'
                '3. USER ACCOUNTS\n'
                '• You must provide accurate information when creating an account\n'
                '• You are responsible for maintaining the security of your account\n'
                '• You must be at least 18 years old to use this service\n\n'
                '4. USER CONDUCT\n'
                '• No fraudulent or misleading information\n'
                '• No harassment or abuse of other users\n'
                '• No illegal activities\n\n'
                '5. TRANSACTIONS\n'
                '• All prices are in South African Rand (ZAR)\n'
                '• Payment terms are agreed between buyer and seller\n'
                '• SpareLink may charge service fees\n\n'
                '6. LIMITATION OF LIABILITY\n'
                'SpareLink is not liable for any disputes between users, quality of parts, or delivery issues.\n\n'
                '7. TERMINATION\n'
                'We reserve the right to terminate accounts that violate these terms.\n\n'
                '8. CHANGES TO TERMS\n'
                'We may update these terms. Continued use constitutes acceptance.\n\n'
                '9. CONTACT\n'
                'For questions: support@sparelink.co.za',
                style: TextStyle(color: AppTheme.lightGray, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _launchUrl(url),
                child: const Text('View Full Terms Online'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showPrivacyDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SpareLink Privacy Policy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Last updated: January 17, 2026\n\n'
                'SpareLink (Pty) Ltd ("we", "us", "our") is committed to protecting your privacy in compliance with POPIA (Protection of Personal Information Act).\n\n'
                '1. INFORMATION WE COLLECT\n'
                '• Personal details: Name, phone number, email address\n'
                '• Location data: For connecting you with nearby suppliers\n'
                '• Vehicle information: For part requests\n'
                '• Transaction history: Orders, quotes, messages\n\n'
                '2. HOW WE USE YOUR INFORMATION\n'
                '• To provide our marketplace service\n'
                '• To connect you with auto parts suppliers\n'
                '• To process transactions\n'
                '• To send service notifications\n'
                '• To improve our services\n\n'
                '3. INFORMATION SHARING\n'
                '• With suppliers: To fulfill your part requests\n'
                '• With service providers: Payment processing, analytics\n'
                '• Legal requirements: When required by law\n\n'
                '4. DATA SECURITY\n'
                '• We use encryption to protect your data\n'
                '• Access is restricted to authorized personnel\n'
                '• Regular security audits\n\n'
                '5. YOUR RIGHTS (POPIA)\n'
                '• Access your personal information\n'
                '• Correct inaccurate information\n'
                '• Delete your account and data\n'
                '• Object to processing\n'
                '• Data portability\n\n'
                '6. DATA RETENTION\n'
                'We retain data for as long as necessary to provide services and comply with legal obligations.\n\n'
                '7. COOKIES\n'
                'We use cookies for authentication and analytics.\n\n'
                '8. CONTACT US\n'
                'Information Officer: privacy@sparelink.co.za',
                style: TextStyle(color: AppTheme.lightGray, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _launchUrl(url),
                child: const Text('View Full Privacy Policy Online'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
