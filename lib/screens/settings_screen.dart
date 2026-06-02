import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../models/emergency_contact.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _contactNameCtrl1 = TextEditingController();
  final _contactPhoneCtrl1 = TextEditingController();
  final _contactNameCtrl2 = TextEditingController();
  final _contactPhoneCtrl2 = TextEditingController();
  final _userService = UserService();
  bool _saved = false;

  // Permission states
  bool _blePerm = false;
  bool _locPerm = false;
  bool _phonePerm = false;
  bool _smsPerm = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPermissions();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _nameCtrl.text = p.getString(PrefKeys.userName) ?? '';
    _phoneCtrl.text = p.getString(PrefKeys.userPhone) ?? '';
    _ageCtrl.text = p.getString('user_age') ?? '';
    final savedContacts = p.getStringList('emergency_contacts_list') ?? [];
    if (savedContacts.isNotEmpty) {
      final c1 = savedContacts[0].split('|');
      if (c1.length >= 2) {
        _contactNameCtrl1.text = c1[0];
        _contactPhoneCtrl1.text = c1[1];
      }
    }
    if (savedContacts.length >= 2) {
      final c2 = savedContacts[1].split('|');
      if (c2.length >= 2) {
        _contactNameCtrl2.text = c2[0];
        _contactPhoneCtrl2.text = c2[1];
      }
    }
    setState(() {});
  }

  Future<void> _checkPermissions() async {
    _blePerm = await Permission.bluetoothConnect.isGranted;
    _locPerm = await Permission.locationWhenInUse.isGranted;
    _phonePerm = await Permission.phone.isGranted;
    _smsPerm = await Permission.sms.isGranted;
    if (mounted) setState(() {});
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.phone,
      Permission.sms,
    ].request();
    await _checkPermissions();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final age = _ageCtrl.text.trim();
    final cName1 = _contactNameCtrl1.text.trim();
    final cPhone1 = _contactPhoneCtrl1.text.trim();
    final cName2 = _contactNameCtrl2.text.trim();
    final cPhone2 = _contactPhoneCtrl2.text.trim();

    if (name.isEmpty || phone.isEmpty || cPhone1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in your name, phone, and at least one contact'),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final p = await SharedPreferences.getInstance();
    await p.setString(PrefKeys.userName, name);
    await p.setString(PrefKeys.userPhone, phone);
    await p.setString('user_age', age);
    await p.setStringList('emergency_contacts_list', [
      '$cName1|$cPhone1',
      if (cPhone2.isNotEmpty) '$cName2|$cPhone2',
    ]);
    await p.setBool(PrefKeys.isSetupComplete, true);

    // --- CLOUD SYNC ---
    try {
      await _userService.saveUserProfile(
        uid: user.uid,
        name: name,
        phoneNumber: phone,
        age: age,
        contacts: [
          EmergencyContact(name: cName1, phoneNumber: cPhone1),
          if (cPhone2.isNotEmpty) EmergencyContact(name: cName2, phoneNumber: cPhone2),
        ],
      );
      
      // Immediately start the NotificationService for the user's phone number
      NotificationService().startListening(phone);
    } catch (e) {
      debugPrint('Cloud sync failed: $e');
    }

    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Settings saved successfully ✓'),
        backgroundColor: AppColors.accentGreen.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _contactNameCtrl1.dispose();
    _contactPhoneCtrl1.dispose();
    _contactNameCtrl2.dispose();
    _contactPhoneCtrl2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // User Profile Card
          _sectionHeader('YOUR PROFILE'),
          _buildCard(
            child: Column(
              children: [
                _buildFocusField(_nameCtrl, 'Full Name', Icons.person_rounded, 'Used in alert dispatches'),
                const SizedBox(height: 14),
                _buildFocusField(_phoneCtrl, 'Your Mobile Number', Icons.phone_android_rounded, 'e.g. +91...', keyboard: TextInputType.phone),
                const SizedBox(height: 14),
                _buildFocusField(_ageCtrl, 'Age Details', Icons.cake_rounded, 'Age', keyboard: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Emergency Contact
          _sectionHeader('PRIMARY GUARDIAN'),
          _buildCard(
            child: Column(
              children: [
                _buildFocusField(_contactNameCtrl1, 'Guardian Name', Icons.contact_emergency_rounded, 'Primary emergency responder'),
                const SizedBox(height: 14),
                _buildFocusField(_contactPhoneCtrl1, 'Guardian Phone', Icons.phone_rounded, 'e.g. +91...', keyboard: TextInputType.phone),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Secondary Emergency Contact
          _sectionHeader('SECONDARY GUARDIAN'),
          _buildCard(
            child: Column(
              children: [
                _buildFocusField(_contactNameCtrl2, 'Guardian Name', Icons.contact_emergency_rounded, 'Backup responder'),
                const SizedBox(height: 14),
                _buildFocusField(_contactPhoneCtrl2, 'Guardian Phone', Icons.phone_rounded, 'e.g. +91...', keyboard: TextInputType.phone),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Permissions Section
          _sectionHeader('SYSTEM INTEGRATIONS'),
          _buildCard(
            child: Column(
              children: [
                _buildPermRow('Bluetooth hardware link', Icons.bluetooth_rounded, _blePerm),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                _buildPermRow('Precise GPS tracker', Icons.gps_fixed_rounded, _locPerm),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                _buildPermRow('Native dialer routing', Icons.call_rounded, _phonePerm),
                const Divider(color: AppColors.surfaceBorder, height: 16),
                _buildPermRow('SMS fallback dispatches', Icons.sms_rounded, _smsPerm),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _requestAllPermissions,
                  icon: const Icon(Icons.security_rounded, size: 18),
                  label: const Text('Sync System Permissions', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentBlue,
                    side: const BorderSide(color: AppColors.accentBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // BLE Device Specifications
          _sectionHeader('HARDWARE PARAMETERS'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildParamRow('Service UUID', '${BleConstants.serviceUuid.substring(0, 18)}...'),
                const SizedBox(height: 8),
                _buildParamRow('Trigger code', BleConstants.sosTriggerCommand),
                const SizedBox(height: 8),
                _buildParamRow('BLE Scan Timeout', '${BleConstants.scanTimeout.inSeconds}s'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppColors.accentGreen : AppColors.accentRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _saved
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        key: ValueKey('done'),
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Saved successfully ✓', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      )
                    : const Text('Save Parameters', key: ValueKey('save'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Button
          TextButton.icon(
            onPressed: () async {
              NotificationService().stopListening();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out Credentials', style: TextStyle(fontWeight: FontWeight.w800)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: child,
    );
  }

  Widget _buildFocusField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {}); // Rebuild for highlight borders
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFocus ? AppColors.accentRed : AppColors.surfaceBorder,
                width: hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: hasFocus ? AppColors.accentRed : AppColors.textSecondary,
                  size: 20,
                ),
                labelText: label,
                labelStyle: TextStyle(
                  color: hasFocus ? AppColors.accentRed : AppColors.textSecondary,
                  fontSize: 13,
                ),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white10, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermRow(String label, IconData icon, bool granted) {
    final statusColor = granted ? AppColors.accentGreen : AppColors.accentRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: granted ? AppColors.accentGreen : AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: statusColor,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  granted ? 'Active' : 'Missing',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
