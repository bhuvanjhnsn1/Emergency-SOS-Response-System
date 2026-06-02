import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import '../services/notification_service.dart';
import '../utils/constants.dart';

class LiveTrackingScreen extends StatefulWidget {
  final EmergencyNotification notification;

  const LiveTrackingScreen({
    super.key,
    required this.notification,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> with SingleTickerProviderStateMixin {
  late StreamSubscription<DatabaseEvent> _dbSubscription;
  double? _liveLat;
  double? _liveLng;
  String _status = "Initializing link...";
  DateTime? _lastSeen;
  late AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _liveLat = widget.notification.latitude;
    _liveLng = widget.notification.longitude;
    _lastSeen = widget.notification.timestamp;

    // Pulse radar animation
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startLiveTracking();
  }

  void _startLiveTracking() {
    final dbRef = FirebaseDatabase.instance.ref("emergencies/${widget.notification.senderUid}");
    _dbSubscription = dbRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final current = data['current'] as Map?;
        final lastSeenTimestamp = data['last_seen'] as int?;
        
        setState(() {
          if (current != null) {
            _liveLat = (current['lat'] as num?)?.toDouble();
            _liveLng = (current['lng'] as num?)?.toDouble();
          }
          if (lastSeenTimestamp != null) {
            _lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenTimestamp);
          }
          _status = "Receiving live GPS stream";
        });
      } else {
        setState(() {
          _status = "Awaiting initial GPS lock from sender...";
        });
      }
    }, onError: (e) {
      setState(() {
        _status = "Stream connection offline";
      });
    });
  }

  Future<void> _callSender() async {
    final phone = widget.notification.senderPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri);
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_liveLat == null || _liveLng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_liveLat,$_liveLng');
    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _dbSubscription.cancel();
    _radarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _liveLat != null && _liveLng != null;
    final lastSeenStr = _lastSeen != null
        ? "${_lastSeen!.hour.toString().padLeft(2, '0')}:${_lastSeen!.minute.toString().padLeft(2, '0')}:${_lastSeen!.second.toString().padLeft(2, '0')}"
        : "Awaiting sync";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Live Tracking Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_tethering_rounded, color: AppColors.accentRed, size: 14),
                SizedBox(width: 6),
                Text('LIVE', style: TextStyle(color: AppColors.accentRed, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sender Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.surface, AppColors.surfaceLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.accentRed.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.accentRed, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.senderName,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.senderPhone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _callSender,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accentGreen.withValues(alpha: 0.15),
                        foregroundColor: AppColors.accentGreen,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.phone_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // Visual Radar Map Simulator
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radar Grid Pattern
                      Positioned.fill(
                        child: CustomPaint(
                          painter: RadarGridPainter(animationValue: _radarCtrl.value),
                        ),
                      ),
                      
                      // Radar Scanning Sweep
                      Positioned.fill(
                        child: RotationTransition(
                          turns: _radarCtrl,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: SweepGradient(
                                center: Alignment.center,
                                colors: [
                                  Colors.transparent,
                                  AppColors.accentRed.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Glowing Marker at center representing target
                      if (hasCoords)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _radarCtrl,
                              builder: (context, child) {
                                return Container(
                                  width: 20 + (_radarCtrl.value * 30),
                                  height: 20 + (_radarCtrl.value * 30),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.accentRed.withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: AppColors.accentRed.withValues(alpha: 1.0 - _radarCtrl.value),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const AbsolutePositionedMarker(),
                          ],
                        ),

                      // Coordinates HUD
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _status,
                                    style: const TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    "Seen: $lastSeenStr",
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              if (hasCoords) ...[
                                const Divider(color: AppColors.surfaceBorder, height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildCoordField("LATITUDE", _liveLat!.toStringAsFixed(7)),
                                    Container(width: 1, height: 28, color: AppColors.surfaceBorder),
                                    _buildCoordField("LONGITUDE", _liveLng!.toStringAsFixed(7)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Panel
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: hasCoords ? _openInGoogleMaps : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'Open Native Route Navigation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class AbsolutePositionedMarker extends StatelessWidget {
  const AbsolutePositionedMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentRed,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentRed.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class RadarGridPainter extends CustomPainter {
  final double animationValue;

  RadarGridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.surfaceBorder.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric circles
    final maxRadius = size.width / 1.5;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (maxRadius / 4) * i, paint);
    }

    // Crosshairs
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);

    // Dynamic radar ripple effect
    final ripplePaint = Paint()
      ..color = AppColors.accentRed.withValues(alpha: 0.15 * (1.0 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, maxRadius * animationValue, ripplePaint);
  }

  @override
  bool shouldRepaint(covariant RadarGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
