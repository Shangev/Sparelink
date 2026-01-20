import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_page_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkMode = true; // Always dark for now
  bool _locationEnabled = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return ResponsivePageLayout(
      maxWidth: ResponsivePageLayout.mediumWidth,
      title: 'Settings',
      showBackButton: !isDesktop,
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Notifications & Appearance
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('NOTIFICATIONS'),
              const SizedBox(height: 12),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      icon: LucideIcons.bell,
                      label: 'Push Notifications',
                      subtitle: 'Receive push notifications',
                      value: _notificationsEnabled,
                      onChanged: (value) => setState(() => _notificationsEnabled = value),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _buildSwitchRow(
                      icon: LucideIcons.volume2,
                      label: 'Sound',
                      subtitle: 'Play sound for notifications',
                      value: _soundEnabled,
                      onChanged: (value) => setState(() => _soundEnabled = value),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _buildSwitchRow(
                      icon: LucideIcons.smartphone,
                      label: 'Vibration',
                      subtitle: 'Vibrate for notifications',
                      value: _vibrationEnabled,
                      onChanged: (value) => setState(() => _vibrationEnabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('APPEARANCE'),
              const SizedBox(height: 12),
              _buildGlassCard(
                child: _buildSwitchRow(
                  icon: LucideIcons.moon,
                  label: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: _darkMode,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Light mode coming soon!'),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right column: Privacy & Data
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('PRIVACY'),
              const SizedBox(height: 12),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      icon: LucideIcons.mapPin,
                      label: 'Location Services',
                      subtitle: 'Allow access to your location',
                      value: _locationEnabled,
                      onChanged: (value) => setState(() => _locationEnabled = value),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMenuRow(
                      icon: LucideIcons.shield,
                      label: 'Privacy Policy',
                      onTap: () => _showPrivacyPolicy(),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMenuRow(
                      icon: LucideIcons.fileText,
                      label: 'Terms of Service',
                      onTap: () => _showTermsOfService(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('DATA'),
              const SizedBox(height: 12),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildMenuRow(
                      icon: LucideIcons.download,
                      label: 'Download My Data',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data download request sent!'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                      },
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _buildMenuRow(
                      icon: LucideIcons.trash2,
                      label: 'Delete Account',
                      iconColor: Colors.red,
                      labelColor: Colors.red,
                      onTap: () => _showDeleteAccountDialog(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildSectionTitle('NOTIFICATIONS'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildSwitchRow(
                icon: LucideIcons.bell,
                label: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.volume2,
                label: 'Sound',
                subtitle: 'Play sound for notifications',
                value: _soundEnabled,
                onChanged: (value) => setState(() => _soundEnabled = value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.smartphone,
                label: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: _vibrationEnabled,
                onChanged: (value) => setState(() => _vibrationEnabled = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('APPEARANCE'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: _buildSwitchRow(
            icon: LucideIcons.moon,
            label: 'Dark Mode',
            subtitle: 'Use dark theme',
            value: _darkMode,
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Light mode coming soon!'),
                  backgroundColor: AppTheme.accentGreen,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('PRIVACY'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildSwitchRow(
                icon: LucideIcons.mapPin,
                label: 'Location Services',
                subtitle: 'Allow access to your location',
                value: _locationEnabled,
                onChanged: (value) => setState(() => _locationEnabled = value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.shield,
                label: 'Privacy Policy',
                onTap: () => _showPrivacyPolicy(),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.fileText,
                label: 'Terms of Service',
                onTap: () => _showTermsOfService(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('DATA'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildMenuRow(
                icon: LucideIcons.download,
                label: 'Download My Data',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data download request sent!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.trash2,
                label: 'Delete Account',
                iconColor: Colors.red,
                labelColor: Colors.red,
                onTap: () => _showDeleteAccountDialog(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SpareLink respects your privacy. We collect minimal data necessary to provide our services:\n\n'
              '• Phone number for authentication\n'
              '• Vehicle information for part requests\n'
              '• Photos for identifying parts\n'
              '• Location data (if enabled) for finding nearby shops\n\n'
              'We do not sell your personal information to third parties.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsOfService() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'By using SpareLink, you agree to:\n\n'
              '• Use the app for legitimate auto parts inquiries\n'
              '• Provide accurate vehicle information\n'
              '• Not engage in fraudulent activities\n'
              '• Respect other users and shops\n\n'
              'SpareLink acts as a marketplace connector and is not responsible for transactions between users and shops.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request submitted. You will receive a confirmation email.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
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

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.accentGreen,
        ),
      ],
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.white).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white,
                fontSize: 16,
              ),
            ),
          ),
          Icon(LucideIcons.chevronRight, color: labelColor ?? Colors.grey, size: 20),
        ],
      ),
    );
  }
}
