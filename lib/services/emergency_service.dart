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
  String? _activeEventId;

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

      final user = FirebaseAuth.instance.currentUser;
      final trackingId = user?.uid ?? 'unknown_user';
      
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(PrefKeys.userName) ?? 'User';
      final userPhone = prefs.getString(PrefKeys.userPhone) ?? '';
      final contactsList = prefs.getStringList('emergency_contacts_list') ?? [];
      final primaryContact = contactsList.isNotEmpty ? contactsList[0].split('|')[1] : '';

      final contactPhones = contactsList.map((entry) {
        final parts = entry.split('|');
        return parts.length >= 2 ? parts[1].trim() : '';
      }).where((phone) => phone.isNotEmpty).toList();

      // Phase 2: Send app alert notification (by writing to Firestore sos_events)
      _updatePhase(EmergencyPhase.sendingSms, 'Pushing alert notification to all guardians...');
      
      // Trigger the emergency event in Firestore
      _activeEventId = await _userService.triggerEmergencyEvent(
        senderUid: trackingId,
        senderName: userName,
        senderPhone: userPhone,
        contactPhones: contactPhones,
        lat: _lastPosition!.latitude,
        lng: _lastPosition!.longitude,
      );

      await Future.delayed(const Duration(seconds: 1));

      // Phase 3: Make phone call to Primary Contact
      if (primaryContact.isNotEmpty) {
        _updatePhase(EmergencyPhase.makingCall, 'Dialing primary contact...');
        final callUri = Uri.parse('tel:$primaryContact');
        final callLaunched = await launcher.launchUrl(callUri);

        if (callLaunched) {
          _startFirebaseTracking(trackingId, userName);
        } else {
          // Even if call fails, we proceed to live tracking because the app alert was pushed
          _startFirebaseTracking(trackingId, userName);
        }
      } else {
        _startFirebaseTracking(trackingId, userName);
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

  /// Reset to idle state and resolve the active SOS event in Firestore
  void reset() {
    _locationSubscription?.cancel();
    _trackingTimer?.cancel();
    _locationSubscription = null;
    _trackingTimer = null;
    _updateCount = 0;
    
    if (_activeEventId != null) {
      final eventId = _activeEventId!;
      _userService.resolveEmergencyEvent(eventId);
      _activeEventId = null;
    }
    
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
