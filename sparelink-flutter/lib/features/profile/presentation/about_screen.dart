import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2C2C2C), Color(0xFF000000)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'About',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        
                        // Logo and App Name
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.accentGreen, width: 2),
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.car, color: AppTheme.accentGreen, size: 50),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'SpareLink',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Version 1.0.0',
                            style: TextStyle(color: AppTheme.accentGreen, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // About Description
                        _buildGlassCard(
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About SpareLink',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'SpareLink is your one-stop marketplace for finding auto spare parts. '
                                'We connect vehicle owners with trusted local shops, making it easy to find '
                                'the parts you need at competitive prices.\n\n'
                                'Simply snap a photo of the part you need, and let our network of verified '
                                'shops provide you with quotes. Compare prices, chat with sellers, and get '
                                'your vehicle back on the road faster.',
                                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Features
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Features',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureRow(LucideIcons.camera, 'Photo-based part requests'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(LucideIcons.store, 'Network of verified shops'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(LucideIcons.messageSquare, 'In-app messaging'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(LucideIcons.dollarSign, 'Competitive pricing'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(LucideIcons.shield, 'Secure transactions'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Social Links
                        _buildGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Follow Us',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSocialButton(context, LucideIcons.facebook, 'Facebook'),
                                  _buildSocialButton(context, LucideIcons.twitter, 'Twitter'),
                                  _buildSocialButton(context, LucideIcons.instagram, 'Instagram'),
                                  _buildSocialButton(context, LucideIcons.linkedin, 'LinkedIn'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Legal
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildLegalRow(context, 'Privacy Policy'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildLegalRow(context, 'Terms of Service'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildLegalRow(context, 'Open Source Licenses'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Copyright
                        Text(
                          '© 2026 SpareLink. All rights reserved.',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Made with ❤️ in South Africa',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  static Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentGreen, size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  static Widget _buildSocialButton(BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $label...'), backgroundColor: AppTheme.accentGreen),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  static Widget _buildLegalRow(BuildContext context, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $label...'), backgroundColor: AppTheme.accentGreen),
        );
      },
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
          const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
