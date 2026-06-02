import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/ble_service.dart';
import '../services/emergency_service.dart';
import '../services/notification_service.dart';
import '../widgets/pulse_button.dart';
import '../widgets/status_card.dart';
import '../widgets/emergency_timeline.dart';
import 'settings_screen.dart';
import 'live_tracking_screen.dart';

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
  
  // Navigation & Notifications State
  int _currentTab = 0;
  StreamSubscription<EmergencyNotification>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _loadSettings();
    _ble.onSosTriggerReceived = () => _ems.executeEmergencyProtocol();
    _ble.addListener(_refresh);
    _ems.addListener(_refresh);

    // Listen for incoming alerts and display the high-priority sliding overlay
    _alertSubscription = NotificationService().onNewEmergencyAlert.listen((alert) {
      _showInAppEmergencyAlert(alert);
    });
    NotificationService().addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    final userPhone = p.getString(PrefKeys.userPhone) ?? '';
    if (userPhone.isNotEmpty) {
      NotificationService().startListening(userPhone);
    }
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
      content: const Text('This will trigger the active emergency protocol:\n\n1. Acquire GPS\n2. Push App Alert Notification\n3. Dial contact\n\nProceed?',
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
      case EmergencyPhase.tracking: return 4;
      case EmergencyPhase.completed: return 5;
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

  // Visual slide-down in-app alert banner
  void _showInAppEmergencyAlert(EmergencyNotification alert) {
    if (!mounted) return;
    
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    ));

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: SlideTransition(
          position: offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                controller.reverse().then((_) {
                  overlayEntry.remove();
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTrackingScreen(notification: alert),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.dangerGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentRed.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    )
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SOS GUARDIAN ALERT!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${alert.senderName} needs assistance. Tap to Track Live.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);
    controller.forward();

    Timer(const Duration(seconds: 8), () {
      if (controller.isCompleted) {
        controller.reverse().then((_) {
          overlayEntry.remove();
        });
      }
    });
  }

  @override
  void dispose() {
    _ble.removeListener(_refresh);
    _ems.removeListener(_refresh);
    NotificationService().removeListener(_refresh);
    _alertSubscription?.cancel();
    _ble.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
          child: _currentTab == 0 ? _buildDashboard() : _buildAlertsTab(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accentBlue,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded),
              label: 'Shield',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined),
                  if (NotificationService().activeNotifications.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.accentRed, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    )
                ],
              ),
              activeIcon: const Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }

  // SOS Dashboard (Tab 0)
  Widget _buildDashboard() {
    final isTracking = _ems.phase == EmergencyPhase.tracking;
    final triggered = _ble.state == BleConnectionState.triggered || _ems.phase != EmergencyPhase.idle;
    final active = _ble.isConnected;
    final c = _bleColor();
    final isScanning = _ble.state == BleConnectionState.scanning || _ble.state == BleConnectionState.connecting;

    return ListView(
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
        Center(child: PulseButton(
          isActive: active, 
          isTriggered: triggered, 
          onPressed: _onPulse,
          onLongPress: _showManualTrigger,
        )),
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

        // Firebase Sync Status (Only during tracking)
        if (_ems.phase == EmergencyPhase.tracking)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Streaming live movement to cloud...',
                    style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

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
        if (_ems.phase == EmergencyPhase.completed || _ems.phase == EmergencyPhase.failed || isTracking)
          ElevatedButton.icon(
            onPressed: () { _ems.reset(); _ble.resetAfterEmergency(); },
            icon: Icon(isTracking ? Icons.stop_circle_rounded : Icons.refresh_rounded),
            label: Text(isTracking ? 'Stop Emergency Tracking' : 'Reset & Reconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking ? AppColors.accentRed.withValues(alpha: 0.2) : AppColors.surfaceLight, 
              foregroundColor: isTracking ? AppColors.accentRed : AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isTracking ? AppColors.accentRed : AppColors.surfaceBorder))),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  // Alerts Tab (Tab 1)
  Widget _buildAlertsTab() {
    final ns = NotificationService();
    final active = ns.activeNotifications;
    final past = ns.pastNotifications;

    if (active.isEmpty && past.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.accentBlue, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                'Guardian Shield Active',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'All configured emergency contacts are secure. You will be alerted instantly if help is requested.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        // Header
        const Text(
          'Alert Center',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          active.isNotEmpty 
              ? '${active.length} active emergency alert(s) detected' 
              : 'All contacts secure • ${past.length} historical logs',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        if (active.isNotEmpty) ...[
          const Text(
            'ACTIVE EMERGENCIES',
            style: TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0),
          ),
          const SizedBox(height: 12),
          ...active.map((alert) => _buildActiveAlertCard(alert)),
          const SizedBox(height: 24),
        ],

        if (past.isNotEmpty) ...[
          const Text(
            'RESOLVED LOGS',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0),
          ),
          const SizedBox(height: 12),
          ...past.map((alert) => _buildResolvedAlertCard(alert)),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildActiveAlertCard(EmergencyNotification alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentRed.withValues(alpha: 0.15), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error_rounded, color: AppColors.accentRed, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.senderName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: ${alert.senderPhone}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(color: AppColors.accentRed, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.surfaceBorder, height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveTrackingScreen(notification: alert)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.radar_rounded, size: 18),
            label: const Text('TRACK LIVE LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedAlertCard(EmergencyNotification alert) {
    final dateStr = "${alert.timestamp.day}/${alert.timestamp.month} ${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.senderName,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'SOS triggered at $dateStr',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Text(
              'RESOLVED',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
