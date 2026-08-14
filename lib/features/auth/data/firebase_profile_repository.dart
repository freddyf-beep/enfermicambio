import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore profile writer used by Firebase Authentication.
///
/// Private account data lives in `users_private/{uid}`. Public identity data
/// is kept separately in `users_public/{uid}` so a feed query never exposes an
/// email address or phone number to another participant.
class FirebaseProfileRepository {
  FirebaseProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _privateProfile(String uid) {
    return _firestore.collection('users_private').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _publicProfile(String uid) {
    return _firestore.collection('users_public').doc(uid);
  }

  Future<void> upsertFromAuthUser(User user) async {
    final now = FieldValue.serverTimestamp();
    final publicData = <String, dynamic>{
      'uid': user.uid,
      'displayName': _bounded(user.displayName, 80),
      'photoUrl': user.photoURL,
      'updatedAt': now,
    };
    final privateData = <String, dynamic>{
      'uid': user.uid,
      'email': _bounded(user.email, 320),
      'phoneNumber': _bounded(user.phoneNumber, 32),
      'emailVerified': user.emailVerified,
      'updatedAt': now,
    };

    await _firestore.runTransaction((transaction) async {
      final privateSnapshot = await transaction.get(_privateProfile(user.uid));
      if (!privateSnapshot.exists) {
        privateData['createdAt'] = now;
      }
      transaction.set(
        _publicProfile(user.uid),
        publicData,
        SetOptions(merge: true),
      );
      transaction.set(
        _privateProfile(user.uid),
        privateData,
        SetOptions(merge: true),
      );
    });
  }

  Future<bool> isMember(String uid) async {
    final snapshot = await _firestore.collection('members').doc(uid).get();
    final data = snapshot.data();
    return snapshot.exists && data?['enabled'] == true;
  }

  static String? _bounded(String? value, int maxLength) {
    if (value == null || value.isEmpty) return null;
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }
}
