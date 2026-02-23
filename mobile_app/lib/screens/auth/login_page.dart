import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _logoController;
  late AnimationController _buttonController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic));

    _buttonFade = CurvedAnimation(parent: _buttonController, curve: Curves.easeOut);
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic));

    // Stagger the animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      const webClientId = '11230700164-1r65gta2trtur4i4aa1squah6jqdv08s.apps.googleusercontent.com';
      const iosClientId = '11230700164-9snokia15lrmavpoeb0nqv8gnokccong.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        clientId: iosClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) throw 'No Access Token found.';
      if (idToken == null) throw 'No ID Token found.';

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Failed: $e",
                style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background Layers (Synced with HomeScreen) ───────────
          // 1. Base Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                colors: [
                  Color(0xFFE0EEFF), // Top: Whitish Blue
                  Color(0xFF0066FF), // Vibrant Blue
                  Color(0xFF001040), // Navy Blue
                  Color(0xFF7C4DFF), // Purple
                  Color(0xFFE0EEFF), // Bottom: Whitish Blue
                ],
                tileMode: TileMode.clamp,
              ),
            ),
          ),
          
          // 2. Navy Circle Element
          OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: const Alignment(0.0, -0.5),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 2.0,
                height: MediaQuery.of(context).size.width * 2.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF000A12),
                      Colors.transparent,
                    ],
                    stops: [0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
          
          // 3. Vignette Overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Center Logo Area
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: Text(
                          'Flox',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Sign-in Section (Minimalist)
                FadeTransition(
                  opacity: _buttonFade,
                  child: SlideTransition(
                    position: _buttonSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                : ElevatedButton(
                                    onPressed: _googleSignIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                          height: 24,
                                          width: 24,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          'Continue with Google',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 24),
                          Text(
                            'By joining, you agree to our Terms & Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// Unused _FloxLogoPainter removed
