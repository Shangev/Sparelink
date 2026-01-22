import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_page_layout.dart';
import '../../../shared/services/settings_service.dart';
import '../../../shared/services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeleting = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final settings = ref.watch(settingsServiceProvider);
    
    return ResponsivePageLayout(
      maxWidth: ResponsivePageLayout.mediumWidth,
      title: 'Settings',
      showBackButton: !isDesktop,
      child: isDesktop ? _buildDesktopLayout(settings) : _buildMobileLayout(settings),
    );
  }
  
  Widget _buildDesktopLayout(SettingsService settings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Notifications & Appearance
        Expanded(
          child: SingleChildScrollView(
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
                        value: settings.notificationsEnabled,
                        onChanged: (value) => settings.setNotificationsEnabled(value),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildSwitchRow(
                        icon: LucideIcons.volume2,
                        label: 'Sound',
                        subtitle: 'Play sound for notifications',
                        value: settings.soundEnabled,
                        onChanged: (value) => settings.setSoundEnabled(value),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildSwitchRow(
                        icon: LucideIcons.smartphone,
                        label: 'Vibration',
                        subtitle: 'Vibrate for notifications',
                        value: settings.vibrationEnabled,
                        onChanged: (value) => settings.setVibrationEnabled(value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionTitle('NOTIFICATION PREFERENCES'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        icon: LucideIcons.tag,
                        label: 'New Quotes',
                        subtitle: 'Get notified when shops send quotes',
                        value: settings.newQuotesNotifications,
                        onChanged: (value) => settings.setNewQuotesNotifications(value),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildSwitchRow(
                        icon: LucideIcons.truck,
                        label: 'Order Updates',
                        subtitle: 'Shipping and delivery notifications',
                        value: settings.orderUpdatesNotifications,
                        onChanged: (value) => settings.setOrderUpdatesNotifications(value),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildSwitchRow(
                        icon: LucideIcons.messageSquare,
                        label: 'Chat Messages',
                        subtitle: 'New messages from shops',
                        value: settings.chatMessagesNotifications,
                        onChanged: (value) => settings.setChatMessagesNotifications(value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionTitle('SOUND CUSTOMIZATION'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildMenuRow(
                        icon: LucideIcons.music,
                        label: 'Quote Alerts',
                        subtitle: settings.quotesSound.displayName,
                        onTap: () => _showSoundSelector(settings, 'quotes'),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildMenuRow(
                        icon: LucideIcons.music,
                        label: 'Order Alerts',
                        subtitle: settings.ordersSound.displayName,
                        onTap: () => _showSoundSelector(settings, 'orders'),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildMenuRow(
                        icon: LucideIcons.music,
                        label: 'Chat Alerts',
                        subtitle: settings.chatSound.displayName,
                        onTap: () => _showSoundSelector(settings, 'chat'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionTitle('APPEARANCE'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        icon: LucideIcons.moon,
                        label: 'Dark Mode',
                        subtitle: 'Use dark theme',
                        value: settings.darkMode,
                        onChanged: (value) {
                          settings.setDarkMode(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(value ? 'Dark mode enabled' : 'Light mode coming soon!'),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildMenuRow(
                        icon: LucideIcons.languages,
                        label: 'Language',
                        subtitle: _getLanguageName(settings.language),
                        onTap: () => _showLanguageSelector(settings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right column: Quiet Hours, Privacy & Data
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('QUIET HOURS'),
                const SizedBox(height: 12),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildSwitchRow(
                        icon: LucideIcons.moonStar,
                        label: 'Do Not Disturb',
                        subtitle: settings.quietHoursEnabled 
                            ? settings.quietHoursDescription 
                            : 'Silence notifications during set hours',
                        value: settings.quietHoursEnabled,
                        onChanged: (value) => settings.setQuietHoursEnabled(value),
                      ),
                      if (settings.quietHoursEnabled) ...[
                        const Divider(color: Colors.white12, height: 24),
                        _buildMenuRow(
                          icon: LucideIcons.clock,
                          label: 'Start Time',
                          subtitle: _formatTimeOfDay(settings.quietHoursStart),
                          onTap: () => _selectQuietHoursTime(settings, isStart: true),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildMenuRow(
                          icon: LucideIcons.clock,
                          label: 'End Time',
                          subtitle: _formatTimeOfDay(settings.quietHoursEnd),
                          onTap: () => _selectQuietHoursTime(settings, isStart: false),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _buildSwitchRow(
                          icon: LucideIcons.calendar,
                          label: 'Include Weekends',
                          subtitle: 'Apply quiet hours on Sat & Sun',
                          value: settings.quietHoursWeekends,
                          onChanged: (value) => settings.setQuietHoursWeekends(value),
                        ),
                      ],
                    ],
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
                        value: settings.locationEnabled,
                        onChanged: (value) => settings.setLocationEnabled(value),
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
                        subtitle: 'Export your personal data',
                        onTap: () => _exportUserData(settings),
                        isLoading: _isExporting,
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      _buildMenuRow(
                        icon: LucideIcons.trash2,
                        label: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        iconColor: Colors.red,
                        labelColor: Colors.red,
                        onTap: () => _showDeleteAccountDialog(settings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout(SettingsService settings) {
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
                value: settings.notificationsEnabled,
                onChanged: (value) => settings.setNotificationsEnabled(value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.volume2,
                label: 'Sound',
                subtitle: 'Play sound for notifications',
                value: settings.soundEnabled,
                onChanged: (value) => settings.setSoundEnabled(value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.smartphone,
                label: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: settings.vibrationEnabled,
                onChanged: (value) => settings.setVibrationEnabled(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('NOTIFICATION PREFERENCES'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildSwitchRow(
                icon: LucideIcons.tag,
                label: 'New Quotes',
                subtitle: 'Get notified when shops send quotes',
                value: settings.newQuotesNotifications,
                onChanged: (value) => settings.setNewQuotesNotifications(value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.truck,
                label: 'Order Updates',
                subtitle: 'Shipping and delivery notifications',
                value: settings.orderUpdatesNotifications,
                onChanged: (value) => settings.setOrderUpdatesNotifications(value),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildSwitchRow(
                icon: LucideIcons.messageSquare,
                label: 'Chat Messages',
                subtitle: 'New messages from shops',
                value: settings.chatMessagesNotifications,
                onChanged: (value) => settings.setChatMessagesNotifications(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('SOUND CUSTOMIZATION'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildMenuRow(
                icon: LucideIcons.music,
                label: 'Quote Alerts',
                subtitle: settings.quotesSound.displayName,
                onTap: () => _showSoundSelector(settings, 'quotes'),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.music,
                label: 'Order Alerts',
                subtitle: settings.ordersSound.displayName,
                onTap: () => _showSoundSelector(settings, 'orders'),
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.music,
                label: 'Chat Alerts',
                subtitle: settings.chatSound.displayName,
                onTap: () => _showSoundSelector(settings, 'chat'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('QUIET HOURS'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildSwitchRow(
                icon: LucideIcons.moonStar,
                label: 'Do Not Disturb',
                subtitle: settings.quietHoursEnabled 
                    ? settings.quietHoursDescription 
                    : 'Silence notifications during set hours',
                value: settings.quietHoursEnabled,
                onChanged: (value) => settings.setQuietHoursEnabled(value),
              ),
              if (settings.quietHoursEnabled) ...[
                const Divider(color: Colors.white12, height: 24),
                _buildMenuRow(
                  icon: LucideIcons.clock,
                  label: 'Start Time',
                  subtitle: _formatTimeOfDay(settings.quietHoursStart),
                  onTap: () => _selectQuietHoursTime(settings, isStart: true),
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildMenuRow(
                  icon: LucideIcons.clock,
                  label: 'End Time',
                  subtitle: _formatTimeOfDay(settings.quietHoursEnd),
                  onTap: () => _selectQuietHoursTime(settings, isStart: false),
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildSwitchRow(
                  icon: LucideIcons.calendar,
                  label: 'Include Weekends',
                  subtitle: 'Apply quiet hours on Sat & Sun',
                  value: settings.quietHoursWeekends,
                  onChanged: (value) => settings.setQuietHoursWeekends(value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('APPEARANCE'),
        const SizedBox(height: 12),
        _buildGlassCard(
          child: Column(
            children: [
              _buildSwitchRow(
                icon: LucideIcons.moon,
                label: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: settings.darkMode,
                onChanged: (value) {
                  settings.setDarkMode(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value ? 'Dark mode enabled' : 'Light mode coming soon!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.languages,
                label: 'Language',
                subtitle: _getLanguageName(settings.language),
                onTap: () => _showLanguageSelector(settings),
              ),
            ],
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
                value: settings.locationEnabled,
                onChanged: (value) => settings.setLocationEnabled(value),
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
                subtitle: 'Export your personal data',
                onTap: () => _exportUserData(settings),
                isLoading: _isExporting,
              ),
              const Divider(color: Colors.white12, height: 24),
              _buildMenuRow(
                icon: LucideIcons.trash2,
                label: 'Delete Account',
                subtitle: 'Permanently delete your account',
                iconColor: Colors.red,
                labelColor: Colors.red,
                onTap: () => _showDeleteAccountDialog(settings),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
  
  String _getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );
    return '${lang.nativeName} (${lang.name})';
  }
  
  void _showLanguageSelector(SettingsService settings) {
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
              'Select Language',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'More languages coming soon!',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...supportedLanguages.map((lang) => ListTile(
              leading: Icon(
                settings.language == lang.code ? LucideIcons.circleCheck : LucideIcons.circle,
                color: settings.language == lang.code ? AppTheme.accentGreen : Colors.grey,
              ),
              title: Text(lang.nativeName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(lang.name, style: TextStyle(color: Colors.grey[500])),
              trailing: lang.code != 'en' 
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Coming Soon', style: TextStyle(color: Colors.orange, fontSize: 10)),
                    )
                  : null,
              onTap: () {
                if (lang.code == 'en') {
                  settings.setLanguage(lang.code);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${lang.name} support coming soon!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Future<void> _exportUserData(SettingsService settings) async {
    setState(() => _isExporting = true);
    
    try {
      final storageService = ref.read(storageServiceProvider);
      final userId = await storageService.getUserId();
      
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final data = await settings.exportUserData(userId);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      
      // Copy to clipboard (web-friendly approach)
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported and copied to clipboard!'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Show data preview dialog
        _showDataPreviewDialog(jsonString);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
  
  void _showDataPreviewDialog(String jsonData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.fileJson, color: AppTheme.accentGreen),
            SizedBox(width: 12),
            Text('Your Data Export', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                jsonData,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!'), backgroundColor: AppTheme.accentGreen),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: const Text('Copy Again'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _selectQuietHoursTime(SettingsService settings, {required bool isStart}) async {
    final initialTime = isStart ? settings.quietHoursStart : settings.quietHoursEnd;
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentGreen,
              onPrimary: Colors.black,
              surface: AppTheme.darkGray,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppTheme.darkGray,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      if (isStart) {
        await settings.setQuietHoursStart(picked);
      } else {
        await settings.setQuietHoursEnd(picked);
      }
    }
  }

  void _showSoundSelector(SettingsService settings, String soundType) {
    NotificationSound currentSound;
    String title;
    
    switch (soundType) {
      case 'quotes':
        currentSound = settings.quotesSound;
        title = 'Quote Alert Sound';
        break;
      case 'orders':
        currentSound = settings.ordersSound;
        title = 'Order Alert Sound';
        break;
      case 'chat':
        currentSound = settings.chatSound;
        title = 'Chat Alert Sound';
        break;
      default:
        currentSound = settings.notificationSound;
        title = 'Notification Sound';
    }
    
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a sound for this notification type',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...NotificationSound.values.map((sound) => ListTile(
              leading: Icon(
                currentSound == sound ? LucideIcons.circleCheck : LucideIcons.circle,
                color: currentSound == sound ? AppTheme.accentGreen : Colors.grey,
              ),
              title: Text(sound.displayName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(sound.description, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: sound != NotificationSound.silent
                  ? IconButton(
                      icon: const Icon(LucideIcons.play, color: AppTheme.accentGreen, size: 20),
                      onPressed: () {
                        // Play preview sound
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Playing ${sound.displayName} sound...'),
                            backgroundColor: AppTheme.accentGreen,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    )
                  : null,
              onTap: () async {
                switch (soundType) {
                  case 'quotes':
                    await settings.setQuotesSound(sound);
                    break;
                  case 'orders':
                    await settings.setOrdersSound(sound);
                    break;
                  case 'chat':
                    await settings.setChatSound(sound);
                    break;
                  default:
                    await settings.setNotificationSound(sound);
                }
                if (mounted) Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
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

  void _showDeleteAccountDialog(SettingsService settings) {
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkGray,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(LucideIcons.triangleAlert, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Text('Delete Account', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'All your data will be permanently deleted, including:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              _buildDeletionItem('Your profile and personal information'),
              _buildDeletionItem('All part requests and history'),
              _buildDeletionItem('Chat messages and conversations'),
              _buildDeletionItem('Saved vehicles and addresses'),
              _buildDeletionItem('Notification history'),
              const SizedBox(height: 16),
              const Text(
                'Type "DELETE" to confirm:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: confirmController.text.toUpperCase() == 'DELETE' && !_isDeleting
                  ? () => _performAccountDeletion(dialogContext, settings)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.grey[800],
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeletionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.x, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13))),
        ],
      ),
    );
  }
  
  Future<void> _performAccountDeletion(BuildContext dialogContext, SettingsService settings) async {
    setState(() => _isDeleting = true);
    
    try {
      final storageService = ref.read(storageServiceProvider);
      final userId = await storageService.getUserId();
      
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Perform deletion
      await settings.deleteAccount(userId);
      
      // Close dialog
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      
      // Navigate to login and show success message
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been permanently deleted.'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deletion failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
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
    String? subtitle,
    Color? iconColor,
    Color? labelColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor ?? Colors.white,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (labelColor ?? Colors.grey).withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: AppTheme.accentGreen, strokeWidth: 2),
            )
          else
            Icon(LucideIcons.chevronRight, color: labelColor ?? Colors.grey, size: 20),
        ],
      ),
    );
  }
}
