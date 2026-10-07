/// Account-specific settings: the Supabase project and Google OAuth clients.
/// All of these are public identifiers, not secrets. When switching to a new
/// account, also update the iOS URL scheme in ios/Runner/Info.plist
/// (the reversed [googleIosClientId]).
class FloxConfig {
  FloxConfig._();

  // Supabase → Project Settings → API.
  static const supabaseUrl = 'https://mvuwesaebtagnxqocjgh.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_m3g5jn9MpCUFq-UuULAJWw_AOs4rUOL';

  // Google Cloud Console → APIs & Services → Credentials.
  static const googleWebClientId = '645596606013-ujbe8lfdge6airsp53cdf5obbvli5kl6.apps.googleusercontent.com';
  // Empty until an iOS client exists for this account; only Android is set up.
  static const googleIosClientId = '';
}
