import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_sync_service.dart';

/// Cloud save on Firebase: Google sign-in through Firebase Auth, and one
/// Firestore document per player at `players/{uid}`:
///
/// ```
/// { progress: <ProgressSnapshot JSON>, updatedAt: <server time> }
/// ```
///
/// Security rules let each player read and write only their own document.
class FirebaseCloudBackend implements CloudBackend {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  Future<void>? _googleReady;

  FirebaseCloudBackend({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('players').doc(uid);

  static CloudUser? _user(User? u) => u == null
      ? null
      : CloudUser(uid: u.uid, email: u.email, name: u.displayName);

  @override
  CloudUser? get currentUser => _user(_auth.currentUser);

  @override
  Stream<CloudUser?> userChanges() => _auth.authStateChanges().map(_user);

  /// Google sign-in reads its web client ID from google-services.json.
  Future<void> _google() => _googleReady ??= GoogleSignIn.instance.initialize();

  /// Shows Google's account picker and returns a Firebase credential, or
  /// null if the player closed it.
  Future<AuthCredential?> _credential() async {
    await _google();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<CloudUser?> signIn() async {
    final credential = await _credential();
    if (credential == null) return null;
    final result = await _auth.signInWithCredential(credential);
    return _user(result.user);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _google();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<Map<String, dynamic>?> load(String uid) async {
    final snap = await _doc(uid).get();
    final progress = snap.data()?['progress'];
    return progress is Map ? Map<String, dynamic>.from(progress) : null;
  }

  @override
  Future<void> save(String uid, Map<String, dynamic> progress) =>
      _doc(uid).set({
        'progress': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteAccount(String uid) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) return;
    await _doc(uid).delete();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Deleting an account needs a recent sign-in; ask once more.
      if (e.code != 'requires-recent-login') rethrow;
      final credential = await _credential();
      if (credential == null) rethrow;
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }
    await _google();
    await GoogleSignIn.instance.disconnect();
  }
}
