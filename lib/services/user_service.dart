import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save or update user profile in Firestore
  Future<void> saveUserProfile({
    required String phoneNumber,
    required String name,
  }) async {
    try {
      // Use phone number as the unique document ID
      final docRef = _db.collection('users').doc(phoneNumber);
      
      await docRef.set({
        'name': name,
        'phone': phoneNumber,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Firestore: User profile saved for $phoneNumber');
    } catch (e) {
      debugPrint('Firestore Error (saveUserProfile): $e');
      rethrow;
    }
  }

  /// Save emergency contacts for a specific user
  Future<void> saveEmergencyContacts({
    required String userPhone,
    required List<EmergencyContact> contacts,
  }) async {
    try {
      final docRef = _db.collection('users').doc(userPhone);
      
      final contactsData = contacts.map((c) => {
        'name': c.name,
        'phone': c.phoneNumber,
      }).toList();

      await docRef.update({
        'contacts': contactsData,
      });
      
      debugPrint('Firestore: ${contacts.length} contacts saved for $userPhone');
    } catch (e) {
      debugPrint('Firestore Error (saveEmergencyContacts): $e');
      rethrow;
    }
  }

  /// Retrieve user profile and contacts from Firestore
  Future<Map<String, dynamic>?> getUserData(String phoneNumber) async {
    try {
      final doc = await _db.collection('users').doc(phoneNumber).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Firestore Error (getUserData): $e');
      return null;
    }
  }

  /// Create a new SOS event record in history
  Future<String> logEmergencyEvent({
    required String userPhone,
    required double lat,
    required double lng,
    required String contactReached,
  }) async {
    try {
      final eventRef = _db.collection('sos_events').doc();
      
      await eventRef.set({
        'user_phone': userPhone,
        'timestamp': FieldValue.serverTimestamp(),
        'initial_location': GeoPoint(lat, lng),
        'guardian_contact': contactReached,
        'status': 'active',
      });
      
      debugPrint('Firestore: Emergency event logged with ID: ${eventRef.id}');
      return eventRef.id;
    } catch (e) {
      debugPrint('Firestore Error (logEmergencyEvent): $e');
      return '';
    }
  }
}
