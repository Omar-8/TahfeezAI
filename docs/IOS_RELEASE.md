# iOS release: the App ID, certificate, profile and keys

Everything is made in a browser and on Linux; no Mac. The build, signing
and upload run on GitHub's Mac runner (`.github/workflows/ios-release.yml`),
the App Store screenshots too (`ios-screenshots.yml`).

Keep the files below (the private key, the `.p12`, the `.p8`) outside the
repository, e.g. in `~/ios-signing/`, and backed up: the `.p8` can be
downloaded once only, and the certificate cannot be rebuilt without its key.

## The app's facts

| | |
|---|---|
| Bundle ID | `ai.tahfeez.tahfeezAi` (fixed once uploaded) |
| Name under the icon | `TahfeezAI` |
| Store name | `Tahfeez AI` (or another if taken; up to 30 characters) |
| Capabilities | none to tick: background audio and the microphone are `Info.plist` entries, the daily reminder is a local notification (no Push Notifications) |
| Devices | iPhone and iPad, iOS 15.1 and later |
| Encryption | none beyond Apple's own (HTTPS): `ITSAppUsesNonExemptEncryption = NO` |
| Version | `pubspec.yaml`'s (`1.0.8+10` → version 1.0.8, build 10) |

## 1. Team ID

developer.apple.com/account → Membership details → **Team ID** (10
characters). GitHub secret `IOS_TEAM_ID`.

## 2. App ID

developer.apple.com/account → Certificates, IDs & Profiles → Identifiers →
**+** → App IDs → App:

- Description: `Tahfeez AI`
- Bundle ID: **Explicit**, `ai.tahfeez.tahfeezAi`
- Capabilities: leave all off → Continue → Register.

## 3. Distribution certificate (made on Linux)

```sh
mkdir -p ~/ios-signing && cd ~/ios-signing
openssl genrsa -out dist.key 2048
openssl req -new -key dist.key -out dist.csr \
  -subj "/emailAddress=<your Apple ID email>/CN=<your name>/C=<country code>"
```

Certificates → **+** → **Apple Distribution** → upload `dist.csr` →
download `distribution.cer` into `~/ios-signing/`. Then:

```sh
openssl x509 -in distribution.cer -inform DER -out dist.pem -outform PEM
# 3DES/SHA-1: the encryption macOS's keychain imports.
openssl pkcs12 -export -inkey dist.key -in dist.pem -out dist.p12 \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
  -passout pass:'<a password>'
```

GitHub secrets `IOS_DIST_P12_BASE64` (`base64 -w0 dist.p12`) and
`IOS_DIST_P12_PASSWORD`. It is valid for a year; renewing it means a new
profile too (step 4).

## 4. Provisioning profile

Profiles → **+** → Distribution: **App Store Connect** → App ID
`ai.tahfeez.tahfeezAi` → the certificate from step 3 → name
`Tahfeez App Store` → download the `.mobileprovision`. GitHub secret
`IOS_PROFILE_BASE64` (`base64 -w0 Tahfeez_App_Store.mobileprovision`).

## 5. The app in App Store Connect

appstoreconnect.apple.com → Apps → **+** → New App:

- Platform iOS; Name `Tahfeez AI`; Primary language English (U.S.)
- Bundle ID: `ai.tahfeez.tahfeezAi` (listed once step 2 is done)
- SKU: `tahfeez-ai` (anything; never shown); User access: Full.

## 6. App Store Connect API key (for the upload)

App Store Connect → Users and Access → Integrations → App Store Connect API
→ Team Keys → **+** → name `GitHub upload`, access **App Manager** →
download `AuthKey_<KEY ID>.p8` (once only). Note the **Key ID** and the
**Issuer ID** shown above the list. GitHub secrets `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` (`base64 -w0 AuthKey_<KEY ID>.p8`).

## 7. The secrets into GitHub

```sh
cd ~/ios-signing
gh secret set IOS_TEAM_ID -R Omar-8/TahfeezAI --body '<team id>'
base64 -w0 dist.p12 | gh secret set IOS_DIST_P12_BASE64 -R Omar-8/TahfeezAI
gh secret set IOS_DIST_P12_PASSWORD -R Omar-8/TahfeezAI --body '<the .p12 password>'
base64 -w0 Tahfeez_App_Store.mobileprovision | gh secret set IOS_PROFILE_BASE64 -R Omar-8/TahfeezAI
gh secret set ASC_KEY_ID -R Omar-8/TahfeezAI --body '<key id>'
gh secret set ASC_ISSUER_ID -R Omar-8/TahfeezAI --body '<issuer id>'
base64 -w0 AuthKey_<KEY ID>.p8 | gh secret set ASC_KEY_P8_BASE64 -R Omar-8/TahfeezAI
```

## 8. Build, TestFlight, review

1. Actions → **iOS release** → Run workflow. The build appears in App Store
   Connect → TestFlight after Apple processes it (~15 min).
2. TestFlight → Internal Testing → add yourself; install the TestFlight app
   on an iPhone and the build from it. Check recitation (the microphone
   and the model), listening with the screen locked, downloads, the daily
   reminder.
3. Actions → **iOS screenshots** → Run workflow → the artifact
   `app-store-media`:
   - `screenshots/<language>/`: `iphone-6.3` (the required iPhone size),
     `iphone-6.9`, `ipad-13` (required), and `duo-inner` / `duo-outer`
     when the runner has an iPhone Duo simulator (optional until April
     2027; uploading them shows the "optimized for iPhone Duo" badge);
   - `previews/`: `iphone.mp4` (886 x 1920, also the Duo's size) and
     `ipad.mp4` (1200 x 1600), a ~27 s tour (`app_preview_test.dart`).
   Recitation shots can be added later from the iPhone itself.
   The product page's header and search-results images:
   `python3 tool/make_app_store_header.py` → `store/app_store/graphics/`.
4. The listing: description and keywords (the Play texts, `store/play/`),
   the privacy policy URL (the site's `#privacy`), App Privacy: **Data Not
   Collected**, age rating, category Reference or Education, price Free.
5. The version → the build → **Add for Review**.
