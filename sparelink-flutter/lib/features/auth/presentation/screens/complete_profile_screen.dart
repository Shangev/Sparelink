import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/storage_service.dart';

/// Complete Profile Screen - Shown after phone verification
/// User fills in: Name, Role (Mechanic/Shop), Workshop Name (if shop)
class CompleteProfileScreen extends ConsumerStatefulWidget {
  final String phone;
  final String userId;
  
  const CompleteProfileScreen({
    super.key,
    required this.phone,
    required this.userId,
  });

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _workshopController = TextEditingController();
  
  String _selectedRole = 'mechanic';
  bool _isLoading = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _workshopController.dispose();
    super.dispose();
  }
  
  /// Redirect shop owners to the Shop Dashboard
  Future<void> _redirectToShopDashboard(String? accessToken) async {
    const shopDashboardUrl = 'http://localhost:3000';
    
    if (kIsWeb) {
      final uri = Uri.parse('$shopDashboardUrl/dashboard?token=$accessToken');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (mounted) {
          _showShopDashboardDialog();
        }
      }
    } else {
      if (mounted) {
        _showShopDashboardDialog();
      }
    }
  }
  
  void _showShopDashboardDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGray,
        title: const Text('Welcome to SpareLink!', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your shop account has been created successfully!',
              style: TextStyle(color: AppTheme.lightGray),
            ),
            SizedBox(height: 16),
            Text(
              'As a shop owner, please use the Shop Dashboard to:',
              style: TextStyle(color: AppTheme.lightGray),
            ),
            SizedBox(height: 8),
            Text('• View part requests from mechanics', style: TextStyle(color: AppTheme.lightGray, fontSize: 13)),
            Text('• Send quotes to customers', style: TextStyle(color: AppTheme.lightGray, fontSize: 13)),
            Text('• Manage orders and deliveries', style: TextStyle(color: AppTheme.lightGray, fontSize: 13)),
            Text('• Set working hours and shop settings', style: TextStyle(color: AppTheme.lightGray, fontSize: 13)),
            SizedBox(height: 16),
            Text(
              'Dashboard: http://localhost:3000',
              style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleCompleteProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      
      // Update the profile in Supabase
      await Supabase.instance.client
          .from('profiles')
          .upsert({
            'id': widget.userId,
            'full_name': _nameController.text.trim(),
            'phone': widget.phone,
            'role': _selectedRole,
          });
      
      // If registering as shop, create shop entry
      if (_selectedRole == 'shop' && _workshopController.text.isNotEmpty) {
        await Supabase.instance.client
            .from('shops')
            .insert({
              'owner_id': widget.userId,
              'name': _workshopController.text.trim(),
              'phone': widget.phone,
            });
      }
      
      // Save user data locally
      await storageService.saveUserData(
        userId: widget.userId,
        role: _selectedRole,
        name: _nameController.text.trim(),
        phone: widget.phone,
      );
      
      if (mounted) {
        // If user is a shop, redirect to shop dashboard
        if (_selectedRole == 'shop') {
          final session = Supabase.instance.client.auth.currentSession;
          await _redirectToShopDashboard(session?.accessToken);
        } else {
          // Navigate to home for mechanics
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlack,
              AppTheme.darkGray,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.accentGreen,
                      size: 48,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Phone Verified!',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your profile to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: AppTheme.glassDecoration(borderRadius: 20),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Phone number display (read-only)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.mediumGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone, color: AppTheme.accentGreen),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.phone,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.verified, color: AppTheme.accentGreen, size: 20),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Role Selection
                            Text(
                              'I am a:',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _RoleButton(
                                    label: 'Mechanic',
                                    icon: Icons.build,
                                    isSelected: _selectedRole == 'mechanic',
                                    onTap: () {
                                      setState(() => _selectedRole = 'mechanic');
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _RoleButton(
                                    label: 'Parts Shop',
                                    icon: Icons.store,
                                    isSelected: _selectedRole == 'shop',
                                    onTap: () {
                                      setState(() => _selectedRole = 'shop');
                                    },
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Name Input
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'John Doe',
                                prefixIcon: Icon(Icons.person),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            
                            // Workshop Name (Only for shops)
                            if (_selectedRole == 'shop') ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _workshopController,
                                decoration: const InputDecoration(
                                  labelText: 'Workshop/Shop Name',
                                  hintText: 'AutoParts Hub',
                                  prefixIcon: Icon(Icons.business),
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (value) {
                                  if (_selectedRole == 'shop' && 
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Please enter your shop name';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            
                            const SizedBox(height: 32),
                            
                            // Complete Profile Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleCompleteProfile,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Complete Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Role Selection Button Widget
class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.accentGreen.withOpacity(0.2) 
              : AppTheme.mediumGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppTheme.accentGreen 
                : AppTheme.glassBorder,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentGreen : AppTheme.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentGreen : AppTheme.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
