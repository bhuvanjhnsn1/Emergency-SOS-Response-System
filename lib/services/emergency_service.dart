import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../utils/constants.dart';
import 'location_service.dart';

/// The current phase of the emergency protocol
enum EmergencyPhase {
  idle,
  acquiringLocation,
  sendingSms,
  makingCall,
  tracking,
  completed,
  failed,
}

/// Orchestrates the full emergency chain: GPS → SMS → Call
class EmergencyService extends ChangeNotifier {
  EmergencyPhase _phase = EmergencyPhase.idle;
  String _statusDetail = '';
  Position? _lastPosition;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _trackingTimer;
  int _updateCount = 0;

  EmergencyPhase get phase => _phase;
  String get statusDetail => _statusDetail;
  Position? get lastPosition => _lastPosition;

  /// Execute the full emergency protocol
  Future<void> executeEmergencyProtocol() async {
    try {
      // Phase 1: Acquire GPS location
      _updatePhase(EmergencyPhase.acquiringLocation, 'Acquiring GPS lock...');
      final position = await LocationService.getCurrentLocation();
      _lastPosition = position;

      final mapsUrl = LocationService.buildMapsUrl(
        position.latitude,
        position.longitude,
      );

      // Load user settings
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(PrefKeys.userName) ?? 'User';
      final contactPhone =
          prefs.getString(PrefKeys.emergencyContactPhone) ?? '';

      if (contactPhone.isEmpty) {
        _updatePhase(
          EmergencyPhase.failed,
          'No emergency contact configured! Please set up in Settings.',
        );
        return;
      }

      // Phase 2: Send SMS
      _updatePhase(EmergencyPhase.sendingSms, 'Sending emergency SMS...');
      final smsBody = Uri.encodeComponent(
        'EMERGENCY: $userName needs help! Location: $mapsUrl',
      );
      final smsUri = Uri.parse('sms:$contactPhone?body=$smsBody');

      final smsLaunched = await launchUrl(smsUri);
      if (!smsLaunched) {
        debugPrint('SMS launch failed, continuing to call phase...');
      }

      // Brief delay before initiating call
      await Future.delayed(const Duration(seconds: 2));

      // Phase 3: Make phone call
      _updatePhase(EmergencyPhase.makingCall, 'Dialing emergency contact...');
      final callUri = Uri.parse('tel:$contactPhone');
      final callLaunched = await launchUrl(callUri);

      if (callLaunched) {
        _startContinuousTracking();
      } else {
        _updatePhase(
          EmergencyPhase.failed,
          'Failed to initiate call. Please dial $contactPhone manually.',
        );
      }
    } catch (e) {
      _updatePhase(
        EmergencyPhase.failed,
        'Emergency protocol error: ${e.toString()}',
      );
    }
  }

  /// Load the configured emergency contact from SharedPreferences
  Future<EmergencyContact?> getEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(PrefKeys.emergencyContactName);
    final phone = prefs.getString(PrefKeys.emergencyContactPhone);
    if (name != null && phone != null) {
      return EmergencyContact(name: name, phoneNumber: phone);
    }
    return null;
  }

  /// Reset to idle state
  void reset() {
    _locationSubscription?.cancel();
    _trackingTimer?.cancel();
    _locationSubscription = null;
    _trackingTimer = null;
    _updateCount = 0;
    _updatePhase(EmergencyPhase.idle, '');
  }

  /// Start background tracking loop
  void _startContinuousTracking() {
    _updatePhase(EmergencyPhase.tracking, 'Live tracking active. Updates every 20s.');
    
    // 1. Subscribe to live GPS stream
    _locationSubscription = LocationService.getLocationStream().listen((pos) {
      _lastPosition = pos;
      notifyListeners();
    });

    // 2. Periodic SMS Update Timer (Every 20 seconds)
    _trackingTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (_phase != EmergencyPhase.tracking) {
        timer.cancel();
        return;
      }

      if (_lastPosition != null) {
        _updateCount++;
        final mapsUrl = LocationService.buildMapsUrl(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
        );
        
        final smsBody = Uri.encodeComponent(
          'UPDATE #$_updateCount: Movement detected. New Location: $mapsUrl',
        );
        
        final prefs = await SharedPreferences.getInstance();
        final contactPhone = prefs.getString(PrefKeys.emergencyContactPhone) ?? '';
        
        if (contactPhone.isNotEmpty) {
          final smsUri = Uri.parse('sms:$contactPhone?body=$smsBody');
          await launchUrl(smsUri);
          debugPrint('Sent tracking SMS update #$_updateCount');
        }
      }
    });
  }

  void _updatePhase(EmergencyPhase newPhase, String detail) {
    _phase = newPhase;
    _statusDetail = detail;
    notifyListeners();
  }
}
