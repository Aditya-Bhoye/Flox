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

        // Retrieve the current session if it exists
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // User is logged in, show the main application screen
          return const HomeScreen();
        } else {
          // User is not logged in, show the login page
          return const LoginPage();
        }
      },
    );
  }
}
