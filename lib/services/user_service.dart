import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save or update user profile and contacts under Auth UID in Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String phoneNumber,
    required String age,
    required List<EmergencyContact> contacts,
  }) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      
      final contactsData = contacts.map((c) => {
        'name': c.name,
        'phone': c.phoneNumber,
      }).toList();

      await docRef.set({
        'name': name,
        'phone': phoneNumber,
        'age': age,
        'contacts': contactsData,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Firestore: User profile saved for $uid');
    } catch (e) {
      debugPrint('Firestore Error (saveUserProfile): $e');
      rethrow;
    }
  }

  /// Retrieve user profile and contacts from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Firestore Error (getUserData): $e');
      return null;
    }
  }

  /// Create a new SOS event record in history
  Future<String> triggerEmergencyEvent({
    required String senderUid,
    required String senderName,
    required String senderPhone,
    required List<String> contactPhones,
    required double lat,
    required double lng,
  }) async {
    try {
      final eventRef = _db.collection('sos_events').doc();
      
      await eventRef.set({
        'sender_uid': senderUid,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'contacts': contactPhones,
        'timestamp': FieldValue.serverTimestamp(),
        'initial_location': GeoPoint(lat, lng),
        'status': 'active',
      });
      
      debugPrint('Firestore: Emergency event logged with ID: ${eventRef.id}');
      return eventRef.id;
    } catch (e) {
      debugPrint('Firestore Error (triggerEmergencyEvent): $e');
      return '';
    }
  }

  /// Resolve an active emergency event
  Future<void> resolveEmergencyEvent(String eventId) async {
    try {
      await _db.collection('sos_events').doc(eventId).update({
        'status': 'resolved',
        'resolved_at': FieldValue.serverTimestamp(),
      });
      debugPrint('Firestore: Emergency event resolved: $eventId');
    } catch (e) {
      debugPrint('Firestore Error (resolveEmergencyEvent): $e');
    }
  }

  /// Legacy helper (kept for compatibility, forwards to triggerEmergencyEvent)
  Future<String> logEmergencyEvent({
    required String userPhone,
    required double lat,
    required double lng,
    required String contactReached,
  }) async {
    return triggerEmergencyEvent(
      senderUid: userPhone,
      senderName: 'User',
      senderPhone: userPhone,
      contactPhones: [contactReached],
      lat: lat,
      lng: lng,
    );
  }
}
