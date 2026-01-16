import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
                        'Help & Support',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text('FREQUENTLY ASKED QUESTIONS',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildFaqItem(context, 'How do I request a part?',
                                  'Tap "Request a Part" on the home screen, take photos of your vehicle/part, select your vehicle details, and submit. Nearby shops will respond with quotes.'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildFaqItem(context, 'How long until I get quotes?',
                                  'Most shops respond within 1-2 hours during business hours. You\'ll receive notifications when new quotes arrive.'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildFaqItem(context, 'Is my information secure?',
                                  'Yes! We use industry-standard encryption and never share your personal data with third parties.'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildFaqItem(context, 'How do I contact a shop?',
                                  'Once you receive a quote, you can chat directly with the shop through our in-app messaging system.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text('CONTACT US',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildContactRow(context, LucideIcons.mail, 'Email Support', 'support@sparelink.co.za'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildContactRow(context, LucideIcons.phone, 'Phone Support', '+27 10 123 4567'),
                              const Divider(color: Colors.white12, height: 24),
                              _buildContactRow(context, LucideIcons.messageCircle, 'WhatsApp', '+27 71 234 5678'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text('BUSINESS HOURS',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildHoursRow('Monday - Friday', '08:00 - 17:00'),
                              const Divider(color: Colors.white12, height: 16),
                              _buildHoursRow('Saturday', '08:00 - 13:00'),
                              const Divider(color: Colors.white12, height: 16),
                              _buildHoursRow('Sunday & Holidays', 'Closed'),
                            ],
                          ),
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

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return GestureDetector(
      onTap: () => _showAnswer(context, question, answer),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(LucideIcons.messageSquare, color: AppTheme.accentGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(question, style: const TextStyle(color: Colors.white, fontSize: 14))),
          const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  void _showAnswer(BuildContext context, String question, String answer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkGray,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(answer, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.black),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $label...'), backgroundColor: AppTheme.accentGreen));
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(value, style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12)),
              ],
            ),
          ),
          const Icon(LucideIcons.externalLink, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildHoursRow(String day, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Text(hours, style: TextStyle(color: hours == 'Closed' ? Colors.red : AppTheme.accentGreen, fontSize: 14)),
      ],
    );
  }
}
