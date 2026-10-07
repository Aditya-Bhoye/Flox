import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'flox_repository.dart';

class AuthService {
  AuthService._();

  static final _googleSignIn = GoogleSignIn(
    serverClientId: FloxConfig.googleWebClientId,
    clientId: FloxConfig.googleIosClientId.isEmpty ? null : FloxConfig.googleIosClientId,
    scopes: const ['email', 'profile'],
  );

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Returns false if the user cancelled. Throws [FloxException] on failure.
  static Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw StateError('Google returned no ID token');

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      return true;
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      throw const FloxException('Sign-in failed. Please try again.');
    }
  }

  /// Signs out of Supabase and Google and deletes this user's data from the
  /// device, so the next account on this phone starts clean.
  static Future<void> signOut() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await FloxRepository.clearLocalData(userId);
    }
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
    // AuthGate reacts to this and shows the login page.
    await _supabase.auth.signOut();
  }
}
