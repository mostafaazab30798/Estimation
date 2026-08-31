# Android release signing

Play releases use **Google Play App Signing**: you enroll an **upload key** in Play Console; Google holds the app signing key and re-signs builds for distribution.

## Local release builds

1. Create or obtain an upload keystore (`.jks` or `.keystore`). Store it **outside** the repo.
2. Copy `android/key.properties.example` to `android/key.properties` (or create the file) with:

```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=<key-alias>
storeFile=<absolute path with forward slashes, or a path relative to android/app/>
```

3. Prefer storing the keystore outside the repository, for example `C:/SecureKeys/Estimation/estimation-upload.jks`. CI temporarily places a decoded copy in `android/app/upload-keystore.jks` on the ephemeral runner.

`android/key.properties` and `*.jks` are gitignored. **Release builds fail** if any required property is missing — there is no debug-key fallback.

## CI (GitHub Actions)

Store these as secrets in a **protected** GitHub Environment (e.g. `production`):

| Secret | Purpose |
|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded upload keystore |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias |
| `KEY_PASSWORD` | Key password |

The release workflow decodes the keystore and writes `android/key.properties`. If any secret is missing, the job **fails**.

## Verify signer on a built artifact

After building an AAB/APK with the upload key:

```bash
# Universal APK from AAB (requires bundletool)
bundletool build-apks --bundle=app-release.aab --output=app.apks --mode=universal
unzip -p app.apks universal.apk > universal.apk

apksigner verify --print-certs universal.apk
```

Record the SHA-256 certificate digest and confirm it matches the upload certificate registered in Play Console → Setup → App signing.

## Key recovery and rotation

- **Upload key lost:** Use Play Console → App signing → **Request upload key reset** (Google reviews the request).
- **Upload key compromised:** Reset the upload key in Play Console and update CI secrets with the new keystore.
- **App signing key:** Managed by Google when Play App Signing is enabled; contact Play support for exceptional cases.

Keep offline backups of the upload keystore and passwords in a secure password manager. Never commit keystores or `key.properties` to version control.

See `docs/release/play-production-setup.md` for the exact Windows generation commands, GitHub `production` environment setup, and first workflow run.
