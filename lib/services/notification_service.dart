import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EmergencyNotification {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderPhone;
  final List<String> contacts;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String status;

  EmergencyNotification({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderPhone,
    required this.contacts,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory EmergencyNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geo = data['initial_location'] as GeoPoint?;
    final ts = data['timestamp'] as Timestamp?;
    return EmergencyNotification(
      id: doc.id,
      senderUid: data['sender_uid'] ?? '',
      senderName: data['sender_name'] ?? 'Unknown User',
      senderPhone: data['sender_phone'] ?? '',
      contacts: List<String>.from(data['contacts'] ?? []),
      timestamp: ts?.toDate() ?? DateTime.now(),
      latitude: geo?.latitude ?? 0.0,
      longitude: geo?.longitude ?? 0.0,
      status: data['status'] ?? 'active',
    );
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _emergencySubscription;
  
  List<EmergencyNotification> _activeNotifications = [];
  List<EmergencyNotification> _pastNotifications = [];
  
  List<EmergencyNotification> get activeNotifications => _activeNotifications;
  List<EmergencyNotification> get pastNotifications => _pastNotifications;

  // Broadcast controller for real-time overlay triggers
  final StreamController<EmergencyNotification> _alertController = StreamController<EmergencyNotification>.broadcast();
  Stream<EmergencyNotification> get onNewEmergencyAlert => _alertController.stream;

  String? _currentUserPhone;

  /// Start listening to SOS events where this user's phone is a contact
  void startListening(String userPhone) {
    if (_currentUserPhone == userPhone && _emergencySubscription != null) {
      return; // Already listening for this user
    }
    
    _currentUserPhone = userPhone;
    _emergencySubscription?.cancel();
    
    debugPrint('NotificationService: Listening for SOS events targeting: $userPhone');
    
    _emergencySubscription = _db
        .collection('sos_events')
        .where('contacts', arrayContains: userPhone)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          final List<EmergencyNotification> activeList = [];
          final List<EmergencyNotification> pastList = [];
          
          for (var doc in snapshot.docs) {
            final notification = EmergencyNotification.fromFirestore(doc);
            if (notification.status == 'active') {
              activeList.add(notification);
            } else {
              pastList.add(notification);
            }
          }

          // Check if there is a newly activated notification that wasn't in our previous active list
          if (activeList.isNotEmpty) {
            for (var active in activeList) {
              final alreadyKnown = _activeNotifications.any((n) => n.id == active.id);
              if (!alreadyKnown) {
                // New alert found! Broadcast it to trigger in-app banner/modal
                _alertController.add(active);
              }
            }
          }
          
          _activeNotifications = activeList;
          _pastNotifications = pastList;
          notifyListeners();
        }, onError: (e) {
          debugPrint('NotificationService Error: $e');
        });
  }

  /// Stop listening and reset
  void stopListening() {
    _emergencySubscription?.cancel();
    _emergencySubscription = null;
    _currentUserPhone = null;
    _activeNotifications.clear();
    _pastNotifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _alertController.close();
    stopListening();
    super.dispose();
  }
}
