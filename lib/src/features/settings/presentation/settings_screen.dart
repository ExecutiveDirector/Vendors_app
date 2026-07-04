import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_settings/app_settings.dart';

import '../../../core/services/local_storage.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/notification_watcher_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/data/auth_api.dart';

/// Real vendor settings, backed by GET/PUT /auth/profile
/// (authController.getProfile / updateProfile) — replaces the previous
/// version of this screen, which was entirely hardcoded mock data
/// ("John Doe", fake sign-out, USD currency default, simulated cache
/// clearing) with no backend calls at all.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _signingOut = false;

  // Live phone notification permission status (Enabled / Disabled / etc.),
  // fetched from FCM rather than assumed — re-checked whenever the vendor
  // returns to this screen, since they may have just come back from
  // toggling it in the phone's system settings.
  AuthorizationStatus? _notifStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Vendor likely just came back from the phone's Settings app after
    // tapping the notifications tile — refresh so the status shown is
    // never stale.
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationStatus();
    }
  }

  Future<void> _refreshNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) setState(() => _notifStatus = settings.authorizationStatus);
  }

  Future<void> _load() async {
    // Show the cached profile from login immediately (no spinner flash),
    // then refresh from the network underneath it.
    final cached = await LocalStorage.getVendorProfile();
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
    }
    try {
      final response = await VendorAuthApi.getProfile();
      final user = response['data']?['user'] as Map<String, dynamic>?;
      if (user != null) {
        await LocalStorage.setVendorProfile(user);
        if (mounted) setState(() {
          _profile = user;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _profile == null) {
        setState(() {
          _error = 'Could not load your profile.';
          _loading = false;
        });
      }
      // If we already have a cached profile shown, a failed refresh is
      // silent — no need to interrupt the vendor with an error banner.
    }
  }

  Future<void> _openEditProfileSheet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: _profile ?? {}),
    );
    if (updated == true) _load();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _signingOut = true);
    try {
      // Best-effort: unregister this device's push token and invalidate
      // the server-side session, then always clear local state regardless
      // of whether either network call succeeds — a vendor must be able
      // to sign out even when offline.
      await PushNotificationService.unregisterToken();
    } catch (_) {}
    try {
      await VendorAuthApi.logout();
    } catch (_) {}

    NotificationWatcherService.instance.reset();
    await LocalStorage.clearAll();

    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Settings'),
      ),
      body: _loading
          ? const AppLoading(message: 'Loading your profile…')
          : _error != null && _profile == null
              ? AppError(message: _error!, onRetry: _load)
              : ListView(
                  children: [
                    _buildProfileCard(cs),
                    _buildSectionHeader('Notifications', cs),
                    _buildNotificationsTile(cs),
                    _buildSectionHeader('Account', cs),
                    _buildChangePasswordTile(),
                    _buildSectionHeader('Support', cs),
                    _buildHelpTile(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signingOut ? null : _confirmSignOut,
                          icon: _signingOut
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Sign Out',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _buildProfileCard(ColorScheme cs) {
    final businessName = _profile?['business_name']?.toString() ?? 'Your Business';
    final contactPerson = _profile?['contact_person']?.toString() ?? '';
    final email = _profile?['business_email']?.toString() ??
        _profile?['email']?.toString() ??
        '';
    final phone = _profile?['business_phone']?.toString() ??
        _profile?['phone_number']?.toString() ??
        '';
    final isVerified = _profile?['is_verified'] == true || _profile?['is_verified'] == 1;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.10), cs.primary.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primary,
            child: Text(
              businessName.isNotEmpty ? businessName[0].toUpperCase() : 'V',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        businessName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified)
                      Icon(Icons.verified, size: 16, color: cs.primary),
                  ],
                ),
                if (contactPerson.isNotEmpty)
                  Text(contactPerson, style: const TextStyle(fontSize: 13)),
                if (email.isNotEmpty)
                  Text(email,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurface.withOpacity(0.6))),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurface.withOpacity(0.6))),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openEditProfileSheet,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Edit Profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationsTile(ColorScheme cs) {
    final (label, color) = switch (_notifStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
        ('Enabled', Colors.green[700]!),
      AuthorizationStatus.denied => ('Disabled', Colors.red[700]!),
      AuthorizationStatus.notDetermined => ('Not set up yet', Colors.grey[600]!),
      _ => ('Checking…', Colors.grey[600]!),
    };
    return ListTile(
      leading: Icon(Icons.notifications_outlined, color: cs.primary),
      title: const Text('Push Notifications'),
      subtitle: Text(
        'Status: $label — tap to open phone settings',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () async {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
        // The listener in didChangeAppLifecycleState also catches this,
        // but refresh immediately too in case the OS doesn't fire a
        // lifecycle event on this particular device.
        _refreshNotificationStatus();
      },
    );
  }

  Widget _buildChangePasswordTile() {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: const Text('Change Password'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _openChangePasswordSheet(),
    );
  }

  Widget _buildHelpTile() {
    return ListTile(
      leading: const Icon(Icons.support_agent_outlined),
      title: const Text('Contact Support'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => context.push('/support'),
    );
  }

  Future<void> _openChangePasswordSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _EditProfileSheet({required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _businessNameController = TextEditingController(
      text: widget.profile['business_name']?.toString() ?? '');
  late final _tradingNameController = TextEditingController(
      text: widget.profile['trading_name']?.toString() ?? '');
  late final _contactPersonController = TextEditingController(
      text: widget.profile['contact_person']?.toString() ?? '');
  late final _businessPhoneController = TextEditingController(
      text: widget.profile['business_phone']?.toString() ?? '');
  late final _businessEmailController = TextEditingController(
      text: widget.profile['business_email']?.toString() ?? '');

  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await VendorAuthApi.updateProfile({
        'business_name': _businessNameController.text.trim(),
        'trading_name': _tradingNameController.text.trim(),
        'contact_person': _contactPersonController.text.trim(),
        'business_phone': _businessPhoneController.text.trim(),
        'business_email': _businessEmailController.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save changes. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _tradingNameController.dispose();
    _contactPersonController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _businessNameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tradingNameController,
                decoration:
                    const InputDecoration(labelText: 'Trading Name (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _businessPhoneController,
                decoration: const InputDecoration(labelText: 'Business Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _businessEmailController,
                decoration: const InputDecoration(labelText: 'Business Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_newController.text.isEmpty || _currentController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await VendorAuthApi.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not change password. Check your current password and try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Change Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Change Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}