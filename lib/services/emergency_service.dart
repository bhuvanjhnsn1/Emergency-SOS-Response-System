import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:telephony/telephony.dart';
import '../models/emergency_contact.dart';
import '../utils/constants.dart';
import 'location_service.dart';
import 'user_service.dart';

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
  final _userService = UserService();
  final Telephony telephony = Telephony.instance;
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

      final user = FirebaseAuth.instance.currentUser;
      final trackingId = user?.uid ?? 'unknown_user';
      final trackingUrl = "https://sos-guardian-tracking.web.app/?id=$trackingId";
      
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(PrefKeys.userName) ?? 'User';
      final contactsList = prefs.getStringList('emergency_contacts_list') ?? [];
      final primaryContact = contactsList.isNotEmpty ? contactsList[0].split('|')[1] : '';

      // Log event to Firestore History
      await _userService.logEmergencyEvent(
        userPhone: trackingId,
        lat: _lastPosition!.latitude,
        lng: _lastPosition!.longitude,
        contactReached: primaryContact,
      );

      // Phase 2: Send SMS to ALL contacts (Directly/Silently)
      _updatePhase(EmergencyPhase.sendingSms, 'Alerting all guardians (Auto-sending)...');
      
      for (var entry in contactsList) {
        final parts = entry.split('|');
        if (parts.length < 2) continue;
        final phone = parts[1];
        if (phone.isEmpty) continue;

        final message = 'EMERGENCY: $userName needs help! Live Tracking: $trackingUrl';
        
        try {
          await telephony.sendSms(
            to: phone,
            message: message,
          );
          debugPrint('SMS sent successfully to $phone');
        } catch (e) {
          debugPrint('Failed to send SMS to $phone: $e');
          // Fallback: Try opening the SMS app if direct sending fails
          final smsUri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
          await launcher.launchUrl(smsUri);
        }
        
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // Brief delay before initiating call
      await Future.delayed(const Duration(seconds: 1));

      // Phase 3: Make phone call to Primary Contact
      _updatePhase(EmergencyPhase.makingCall, 'Dialing primary contact...');
      final callUri = Uri.parse('tel:$primaryContact');
      final callLaunched = await launcher.launchUrl(callUri);

      if (callLaunched) {
        _startFirebaseTracking(trackingId, userName);
      } else {
        _updatePhase(
          EmergencyPhase.failed,
          'Failed to initiate call. Please dial $primaryContact manually.',
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

  /// Start background tracking loop using Firebase
  void _startFirebaseTracking(String trackingId, String userName) {
    _updatePhase(EmergencyPhase.tracking, 'Invisible Live Tracking Active');
    
    final dbRef = FirebaseDatabase.instance.ref("emergencies/$trackingId");

    // 1. Subscribe to live GPS stream
    _locationSubscription = LocationService.getLocationStream().listen((pos) {
      _lastPosition = pos;
      notifyListeners();
    });

    // 2. Periodic Firebase Update Timer (Every 15 seconds)
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_phase != EmergencyPhase.tracking) {
        timer.cancel();
        return;
      }

      if (_lastPosition != null) {
        _updateCount++;
        
        try {
          // Push silent update to Firebase
          await dbRef.update({
            "name": userName,
            "last_seen": ServerValue.timestamp,
            "current": {
              "lat": _lastPosition!.latitude,
              "lng": _lastPosition!.longitude,
            },
            "history/${DateTime.now().millisecondsSinceEpoch}": {
              "lat": _lastPosition!.latitude,
              "lng": _lastPosition!.longitude,
            }
          });
          debugPrint('Firebase Sync #$_updateCount successful');
        } catch (e) {
          debugPrint('Firebase Sync Error: $e');
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
