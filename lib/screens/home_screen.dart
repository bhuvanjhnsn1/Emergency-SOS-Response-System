import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/ble_service.dart';
import '../services/emergency_service.dart';
import '../widgets/pulse_button.dart';
import '../widgets/status_card.dart';
import '../widgets/emergency_timeline.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final BleService _ble = BleService();
  final EmergencyService _ems = EmergencyService();
  String _userName = 'User';
  String _contactName = '';
  String _contactPhone = '';
  bool _setupDone = false;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _loadSettings();
    _ble.onSosTriggerReceived = () => _ems.executeEmergencyProtocol();
    _ble.addListener(_refresh);
    _ems.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _userName = p.getString(PrefKeys.userName) ?? 'User';
      _contactName = p.getString(PrefKeys.emergencyContactName) ?? '';
      _contactPhone = p.getString(PrefKeys.emergencyContactPhone) ?? '';
      _setupDone = p.getBool(PrefKeys.isSetupComplete) ?? false;
    });
  }

  void _onPulse() {
    if (!_setupDone) { _showSetupDialog(); return; }
    final s = _ble.state;
    if (s == BleConnectionState.disconnected || s == BleConnectionState.error) {
      _ble.startScanning();
    } else if (s == BleConnectionState.connected) {
      _showManualTrigger();
    }
  }

  void _showSetupDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Setup Required', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Please configure your name and emergency contact.', style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(ctx); _goSettings(); },
          child: const Text('Set Up', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _showManualTrigger() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange),
        SizedBox(width: 10),
        Text('Manual SOS Test', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      ]),
      content: const Text('This will trigger the full emergency protocol:\n\n1. Acquire GPS\n2. Send SMS\n3. Dial contact\n\nProceed?',
        style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(ctx); _ems.executeEmergencyProtocol(); },
          child: const Text('TRIGGER SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _goSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    _loadSettings();
  }

  int _timelineStep() {
    switch (_ems.phase) {
      case EmergencyPhase.acquiringLocation: return 1;
      case EmergencyPhase.sendingSms: return 2;
      case EmergencyPhase.makingCall: return 3;
      case EmergencyPhase.completed: return 4;
      default: return 0;
    }
  }

  Color _bleColor() {
    switch (_ble.state) {
      case BleConnectionState.connected: return AppColors.statusActive;
      case BleConnectionState.scanning:
      case BleConnectionState.connecting: return AppColors.accentBlue;
      case BleConnectionState.triggered: return AppColors.statusDanger;
      case BleConnectionState.error: return AppColors.statusDanger;
      case BleConnectionState.disconnected: return AppColors.statusInactive;
    }
  }

  String _bleSub() {
    switch (_ble.state) {
      case BleConnectionState.connected: return 'Connected — Listening for SOS';
      case BleConnectionState.scanning: return 'Scanning for ESP32-C3...';
      case BleConnectionState.connecting: return 'Establishing link...';
      case BleConnectionState.triggered: return '🚨 SOS command received!';
      case BleConnectionState.error: return 'Connection error';
      case BleConnectionState.disconnected: return 'Not connected';
    }
  }

  @override
  void dispose() {
    _ble.removeListener(_refresh);
    _ems.removeListener(_refresh);
    _ble.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final triggered = _ble.state == BleConnectionState.triggered || _ems.phase != EmergencyPhase.idle;
    final active = _ble.isConnected;
    final c = _bleColor();
    final isScanning = _ble.state == BleConnectionState.scanning || _ble.state == BleConnectionState.connecting;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 16),
              // Header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SOS Guardian', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(_setupDone ? 'Protecting $_userName' : 'Setup required', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ]),
                GestureDetector(
                  onTap: _goSettings,
                  child: Container(width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceBorder)),
                    child: const Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 22)),
                ),
              ]),
              const SizedBox(height: 32),
              // Pulse Button
              Center(child: PulseButton(isActive: active, isTriggered: triggered, onPressed: _onPulse)),
              const SizedBox(height: 20),
              // Status pill
              Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: c.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isScanning) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c))
                  else Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)])),
                  const SizedBox(width: 10),
                  Flexible(child: Text(_ble.statusMessage, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                ]),
              )),
              const SizedBox(height: 28),
              // Emergency Timeline
              if (_ems.phase != EmergencyPhase.idle) ...[
                EmergencyTimeline(currentStep: _timelineStep(), hasError: _ems.phase == EmergencyPhase.failed),
                const SizedBox(height: 12),
              ],
              // Emergency detail
              if (_ems.statusDetail.isNotEmpty)
                _buildDetailBanner(),
              // Section label
              const Padding(padding: EdgeInsets.only(top: 8, bottom: 12),
                child: Text('SYSTEM STATUS', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0))),
              // Cards
              StatusCard(icon: Icons.bluetooth_rounded, title: 'ESP32-C3 Link', subtitle: _bleSub(), iconColor: _bleColor()),
              const SizedBox(height: 10),
              StatusCard(icon: Icons.gps_fixed_rounded, title: 'GPS Location',
                subtitle: _ems.lastPosition != null ? '${_ems.lastPosition!.latitude.toStringAsFixed(6)}, ${_ems.lastPosition!.longitude.toStringAsFixed(6)}' : 'Awaiting GPS lock',
                iconColor: _ems.lastPosition != null ? AppColors.accentGreen : AppColors.textMuted),
              const SizedBox(height: 10),
              StatusCard(icon: Icons.contact_emergency_rounded, title: 'Emergency Contact',
                subtitle: _contactName.isNotEmpty ? '$_contactName  •  $_contactPhone' : 'Not configured — Tap to set up',
                iconColor: _contactName.isNotEmpty ? AppColors.accentPurple : AppColors.statusWarning, onTap: _goSettings),
              const SizedBox(height: 16),
              // Reset button
              if (_ems.phase == EmergencyPhase.completed || _ems.phase == EmergencyPhase.failed)
                ElevatedButton.icon(
                  onPressed: () { _ems.reset(); _ble.resetAfterEmergency(); },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset & Reconnect'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceLight, foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.surfaceBorder))),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBanner() {
    final isFail = _ems.phase == EmergencyPhase.failed;
    final isDone = _ems.phase == EmergencyPhase.completed;
    final bc = isFail ? AppColors.accentRed : isDone ? AppColors.accentGreen : AppColors.accentOrange;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: bc.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(isDone ? Icons.check_circle_rounded : isFail ? Icons.error_rounded : Icons.info_outline_rounded, color: bc, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(_ems.statusDetail, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
      ]),
    );
  }
}
