# Flox

Split expenses with friends. Flutter app with Google sign-in and a Supabase
backend.

```
lib/          Flutter app code (Android, iOS)
test/         Unit tests
supabase/     Database schema + Row Level Security policies
```

## One-time setup

### 1. Database

In the Supabase dashboard open **SQL Editor → New query**, paste
[`supabase/schema.sql`](supabase/schema.sql) and run it. It creates the
`friends`, `split_items` and `split_debts` tables, turns on Row Level Security
so each user can only read and write their own rows, and adds the
`create_split` function that saves a split and its debts in one transaction.

Check afterwards under **Authentication → Policies** that all three tables show
RLS as enabled.

### 2. Google sign-in (app ID is `com.flox.app`)

The app ID changed from `com.example.mobile_app`, so the old Google OAuth
clients no longer match. In Google Cloud Console → **APIs & Services →
Credentials**:

- **Android:** create an OAuth client of type Android with package name
  `com.flox.app` and the SHA-1 of every key you sign with. Get the SHA-1s with
  `cd android && gradlew signingReport` (debug key) and
  `keytool -list -v -keystore <your .jks>` (release key).
- **iOS:** create an OAuth client of type iOS with bundle ID `com.flox.app`,
  then update `googleIosClientId` in `lib/config.dart` and
  the reversed client ID URL scheme in `ios/Runner/Info.plist`.
- In Supabase → **Authentication → Providers → Google**, add the new client IDs
  to *Authorized Client IDs*.

### 3. Release signing key (Android)

Release builds refuse to build without a real key.

```
keytool -genkey -v -keystore %USERPROFILE%\flox-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `key.properties` (it is
git-ignored) and fill in the passwords and path. Back up the `.jks` file and
passwords: without them you cannot publish updates.

## Run

```
flutter pub get
flutter run
```

From WSL, call the Windows Flutter through `cmd.exe /c "flutter ..."`.

## Test

```
flutter test
```

## Release build

```
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols` for each release so you can read crash stack traces.

## How data is stored

- Supabase is the source of truth. Each user only ever sees their own rows
  (Row Level Security).
- Money is stored as whole paise (`bigint`), so splits always add up exactly.
- Friends are identified by ID, not by name, so two friends called "Rahul"
  have separate balances. Removing a friend hides them but keeps their history.
- The device keeps an encrypted per-user cache (Android Keystore / iOS
  Keychain) so the app opens instantly and works read-only offline. It is
  excluded from backups and deleted on sign-out.
- Fonts (Inter, OFL licence) and images are bundled; the app makes no requests
  to third-party servers apart from Google sign-in and Supabase.

## Monthly summary email

On the 1st of every month at 9:00 AM IST, each user gets an email from
floxsplitapp@gmail.com with last month's expenses, totals per friend and what
is still remaining. Code: `supabase/functions/monthly-summary/index.ts`;
schedule: `supabase/monthly_email.sql`.

Setup: create a Gmail App Password for floxsplitapp@gmail.com, deploy the
function with JWT verification off, set the secrets `GMAIL_USER`,
`GMAIL_APP_PASSWORD` and `CRON_SECRET`, then run `monthly_email.sql` with the
same `CRON_SECRET`.
