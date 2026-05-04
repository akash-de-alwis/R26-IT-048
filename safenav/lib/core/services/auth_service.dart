import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '946158737363-ih2tv0r5tub1op1ltrk3qe7qi82ntgi1.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  User? currentUser;
  bool isLoading = false;
  String? errorMessage;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      currentUser = user;
      notifyListeners();
    });
  }

  bool get isSignedIn => currentUser != null;

  String get userName => currentUser?.displayName ?? 'SafeNav User';

  String get userEmail => currentUser?.email ?? '';

  String get userPhotoUrl => currentUser?.photoURL ?? '';

  String get userInitials {
    final name = currentUser?.displayName ?? '';
    if (name.isEmpty) return 'SN';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<bool> signInWithGoogle() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      currentUser = userCredential.user;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      debugPrint('[AuthService] Sign-in error (${e.runtimeType}): $e');
      if (e.toString().contains('ApiException: 10') ||
          e.toString().contains('sign_in_failed')) {
        errorMessage =
            'Google Sign-In not configured for this device. Please contact support.';
      } else if (e.toString().contains('network_error') ||
          e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Check your internet connection.';
      } else {
        errorMessage = 'Sign-in failed. Please try again.';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentUser = null;
    notifyListeners();
  }
}
