# Play production environment setup

The repository has a fail-closed Play workflow at `.github/workflows/play-release.yml`. It uses the protected GitHub environment named `production`, runs analysis/tests, signs an Android App Bundle, and uploads the AAB, R8 mapping, and native-symbol artifacts.

It does **not** currently submit the bundle to Play Console automatically. First releases should be downloaded from the workflow and uploaded to the Play internal track manually while Play App Signing is enrolled.

## 1. Preconditions

- Permanent application ID confirmed as `com.mostafaazab.estimation`.
- GitHub account has admin access to `mostafaazab30798/Estimation`.
- Play Console app has not been associated with a different upload certificate.
- `keytool` is installed (`where.exe keytool`).
- Secure password manager and encrypted offline backup location are ready.

If this package has already been uploaded to Play, inspect **Play Console → Setup → App signing** before generating anything. Use the registered upload key or request an upload-key reset; do not silently replace it.

## 2. Create the upload key locally

Run PowerShell. The command prompts for passwords; do not place passwords directly on the command line.

```powershell
New-Item -ItemType Directory -Force -Path "C:\SecureKeys\Estimation"

keytool -genkeypair -v `
  -keystore "C:\SecureKeys\Estimation\estimation-upload.jks" `
  -storetype JKS `
  -alias estimation-upload `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -dname "CN=Hope TV, OU=Mobile, O=Hope TV, L=Riyadh, ST=Riyadh, C=SA"
```

Create the gitignored local file `android/key.properties`:

```properties
storePassword=<secret>
keyPassword=<secret>
keyAlias=estimation-upload
storeFile=C:/SecureKeys/Estimation/estimation-upload.jks
```

Export the public upload certificate and record its SHA-256 fingerprint:

```powershell
keytool -exportcert -rfc `
  -keystore "C:\SecureKeys\Estimation\estimation-upload.jks" `
  -alias estimation-upload `
  -file "C:\SecureKeys\Estimation\estimation-upload-certificate.pem"

keytool -list -v `
  -keystore "C:\SecureKeys\Estimation\estimation-upload.jks" `
  -alias estimation-upload
```

Keep two encrypted backups of the `.jks` and its passwords. The `.pem` certificate/fingerprint is public; the `.jks` and passwords are private.

## 3. Create the protected GitHub environment

In GitHub:

1. Open **Settings → Environments → New environment**.
2. Name it exactly `production`.
3. Add required reviewers and prevent self-review if another trusted maintainer is available.
4. Restrict deployment branches/tags to the protected release policy.
5. Add these **environment secrets**, not repository variables:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 of `estimation-upload.jks` |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | `estimation-upload` |
| `KEY_PASSWORD` | Key password |

Generate the Base64 value without writing an extra plaintext file:

```powershell
$uploadKeyBytes = [System.IO.File]::ReadAllBytes(
  "C:\SecureKeys\Estimation\estimation-upload.jks"
)
$uploadKeyBase64 = [Convert]::ToBase64String($uploadKeyBytes)
$uploadKeyBase64 | Set-Clipboard
```

Paste it into `ANDROID_KEYSTORE_BASE64`, then clear the clipboard after saving:

```powershell
Set-Clipboard -Value ""
Remove-Variable uploadKeyBytes, uploadKeyBase64
```

The GitHub CLI on the audit machine currently has an expired token. If CLI setup is preferred, first run `gh auth login -h github.com`, create the environment in GitHub, and use `gh secret set <NAME> --env production` so each value is entered through standard input.

## 4. Run and verify `play-release`

For the first run, use **Actions → Play Release (AAB) → Run workflow** from a reviewed commit on `main`. The job should pause for the `production` reviewer and then:

1. Check that version code `22` is greater than the recorded Play baseline `21`.
2. Run `flutter test` and `flutter analyze`.
3. Fail if any signing secret is absent.
4. Build `build/app/outputs/bundle/release/app-release.aab`.
5. Upload AAB, R8 mapping, and native symbols as workflow artifacts.

Download the AAB, upload it to Play's internal track, enroll in Play App Signing, and confirm the **upload certificate** matches the local upload certificate. The **app-signing certificate** shown by Play is the fingerprint used for Google Sign-In production configuration and `assetlinks.json`.

After Play accepts version code 22, update `android/last_play_version_code.txt` to `22` in the next release-preparation commit. Every later `pubspec.yaml` build number must be higher.

## 5. Separate Cloudflare Pages legal site

The Flutter web app remains unchanged. Legal pages are deployed from a separate static directory and workflow to a separate Cloudflare Pages project:

- `legal-site/privacy/index.html` → `https://legal.hope-tv.site/privacy/`
- `legal-site/account-deletion/index.html` → `https://legal.hope-tv.site/account-deletion/`
- `.github/workflows/legal-site-deploy.yml` → deploys only `legal-site/`

Before using the URLs in Play Console:

1. Create a separate Cloudflare Pages Direct Upload project named `estimation-legal` (or set GitHub variable `CLOUDFLARE_LEGAL_PAGES_PROJECT` to the chosen name).
2. Attach `legal.hope-tv.site` as that project's custom domain. Do not attach or modify the Flutter web app's existing domain/project.
3. Confirm the GitHub `production` environment has `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
4. Activate and monitor `privacy@hope-tv.site` (Cloudflare Email Routing or another mailbox provider).
5. Run **Deploy Legal Site** manually, or push a reviewed `legal-site/**` change to `main`.
6. Verify both URLs over HTTPS in a signed-out browser and on mobile.
7. Test the deletion email button and complete a real test-account deletion end to end.

Do not claim account deletion is operational merely because the page loads. The verified mailbox workflow and Supabase deletion/cascade checks in `docs/privacy/data-inventory.md` must also pass.
