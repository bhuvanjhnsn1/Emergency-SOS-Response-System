import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
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
    _contactNameCtrl.text = p.getString(PrefKeys.emergencyContactName) ?? '';
    _contactPhoneCtrl.text = p.getString(PrefKeys.emergencyContactPhone) ?? '';
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
    final cName = _contactNameCtrl.text.trim();
    final cPhone = _contactPhoneCtrl.text.trim();

    if (name.isEmpty || cName.isEmpty || cPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in all fields'),
        backgroundColor: AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.setString(PrefKeys.userName, name);
    await p.setString(PrefKeys.emergencyContactName, cName);
    await p.setString(PrefKeys.emergencyContactPhone, cPhone);
    await p.setBool(PrefKeys.isSetupComplete, true);

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
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // User Profile Section
          _sectionLabel('YOUR PROFILE'),
          const SizedBox(height: 12),
          _buildField(_nameCtrl, 'Your Name', Icons.person_rounded, 'Used in the SOS message'),
          const SizedBox(height: 28),

          // Emergency Contact Section
          _sectionLabel('EMERGENCY CONTACT'),
          const SizedBox(height: 12),
          _buildField(_contactNameCtrl, 'Contact Name', Icons.contact_emergency_rounded, 'Who to notify'),
          const SizedBox(height: 14),
          _buildField(_contactPhoneCtrl, 'Phone Number', Icons.phone_rounded, 'Include country code (e.g. +91...)', keyboard: TextInputType.phone),
          const SizedBox(height: 28),

          // Permissions Section
          _sectionLabel('PERMISSIONS'),
          const SizedBox(height: 12),
          _buildPermRow('Bluetooth', Icons.bluetooth_rounded, _blePerm),
          _buildPermRow('Location', Icons.gps_fixed_rounded, _locPerm),
          _buildPermRow('Phone', Icons.call_rounded, _phonePerm),
          _buildPermRow('SMS', Icons.sms_rounded, _smsPerm),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _requestAllPermissions,
            icon: const Icon(Icons.security_rounded, size: 18),
            label: const Text('Grant All Permissions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentBlue,
              side: const BorderSide(color: AppColors.accentBlue),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 28),

          // BLE Info Section
          _sectionLabel('DEVICE INFO'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder.withValues(alpha: 0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('Service UUID', '${BleConstants.serviceUuid.substring(0, 18)}...'),
              const SizedBox(height: 8),
              _infoRow('Trigger', BleConstants.sosTriggerCommand),
              const SizedBox(height: 8),
              _infoRow('Scan Timeout', '${BleConstants.scanTimeout.inSeconds}s'),
            ]),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppColors.accentGreen : AppColors.accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _saved
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, key: ValueKey('done'), children: [
                      Icon(Icons.check_rounded, color: Colors.white), SizedBox(width: 8),
                      Text('Saved!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ])
                  : const Text('Save Settings', key: ValueKey('save'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0));

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, String hint, {TextInputType keyboard = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.accentBlue, size: 22),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPermRow(String label, IconData icon, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: granted ? AppColors.accentGreen : AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: (granted ? AppColors.accentGreen : AppColors.accentRed).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(granted ? 'Granted' : 'Denied',
            style: TextStyle(color: granted ? AppColors.accentGreen : AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(children: [
      Text('$label: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      Expanded(child: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
    ]);
  }
}
