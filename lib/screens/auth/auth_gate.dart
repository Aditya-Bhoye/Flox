import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Listen to the current authentication state from Supabase
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1115),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) return const LoginPage();

        // Keyed by user so a different account never reuses the previous
        // account's in-memory state.
        return HomeScreen(key: ValueKey(session.user.id), userId: session.user.id);
      },
    );
  }
}
