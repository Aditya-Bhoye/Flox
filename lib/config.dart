/// Account-specific settings: the Supabase project and Google OAuth clients.
/// All of these are public identifiers, not secrets. When switching to a new
/// account, also update the iOS URL scheme in ios/Runner/Info.plist
/// (the reversed [googleIosClientId]).
class FloxConfig {
  FloxConfig._();

  // Supabase → Project Settings → API.
  static const supabaseUrl = 'https://yomyhrmbniiexwwweuwk.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_ntuEojbcZPUGrgY7I1smXA_DXSdOTDV';

  // Google Cloud Console → APIs & Services → Credentials.
  static const googleWebClientId = '1070145833168-199kgmll96d86bik7deg4vdr7gh8j061.apps.googleusercontent.com';
  // Empty until an iOS client exists for this account; only Android is set up.
  static const googleIosClientId = '';
}
