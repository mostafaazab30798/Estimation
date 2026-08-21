# How to Publish a New App Update

This guide walks you through every step to release a new version of the Estimation app.
Users will see an **"تحديث الآن"** button inside the app that downloads and installs the new APK automatically.

---

## Overview of the Full Update Flow

```
1. Bump version in pubspec.yaml + kAppVersion constant
          ↓
2. Build release APK
          ↓
3. Create a GitHub Release and upload the APK as an asset
          ↓
4. Copy the direct download link
          ↓
5. Run one SQL UPDATE in Supabase (new version + release notes + download link)
          ↓
Users tap "التحقق من التحديثات" in the Profile screen
          ↓
Update dialog appears → user taps "تحديث الآن"
          ↓
APK downloads with a live progress bar
          ↓
Android installer launches automatically → done
```

---

## Step 1 — Bump the Version in Two Places

### 1a. `pubspec.yaml`

```yaml
# Before
version: 0.1.0+1

# After (example patch release)
version: 0.1.1+2
```

| Part           | When to increment                                      |
|----------------|--------------------------------------------------------|
| `MAJOR`        | Breaking change / complete redesign                    |
| `MINOR`        | New feature added, backward compatible                 |
| `PATCH`        | Bug fixes or small improvements only                   |
| `BUILD_NUMBER` | Always +1 on every release (Android versionCode)       |

### 1b. `lib/services/update_checker_service.dart`

Open the file and change `kAppVersion` to match the version **before the `+`**:

```dart
const String kAppVersion = '0.1.1';   // ← bump this, no +build suffix
```

> [!IMPORTANT]
> Both places must match. If `pubspec.yaml` says `0.1.1+2`, set `kAppVersion = '0.1.1'`.

---

## Step 2 — Build the Release APK

```bash
flutter build apk --release
```

The output APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

Rename it to something descriptive before uploading:
```
estimation-v0.1.1.apk
```

---

## Step 3 — Create a GitHub Release & Upload the APK

This is where the direct download link comes from.

1. Go to your GitHub repository
2. Click **Releases** → **Draft a new release**
3. Set the tag to `v0.1.1` (must match the version)
4. Set the release title, e.g. `v0.1.1 — Bug fixes`
5. Drag and drop `estimation-v0.1.1.apk` into the **Assets** section
6. Click **Publish release**

### Get the direct download link

After publishing, click the uploaded `.apk` asset. The URL will look like:

```
https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v0.1.1/estimation-v0.1.1.apk
```

Copy this — you will need it in Step 4.

> [!IMPORTANT]
> The link must be **publicly accessible** (no private repo auth). Test it by pasting it
> in a browser — it should start downloading immediately without any login.

---

## Step 4 — Update Supabase

Go to your **Supabase dashboard → SQL Editor** and run:

```sql
UPDATE app_version
SET
  latest_version = '0.1.1',
  release_notes  = '• إصلاح خطأ في شاشة التسجيل
• تحسين الأداء العام
• واجهة جديدة لشاشة الملف الشخصي',
  download_url   = 'https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v0.1.1/estimation-v0.1.1.apk',
  updated_at     = now()
WHERE id = 1;
```

Replace `latest_version`, `release_notes`, and `download_url` with your actual values.

### Verify the row

```sql
SELECT id, latest_version, release_notes, download_url, updated_at
FROM app_version
WHERE id = 1;
```

---

## Step 5 — First-Time Supabase Setup (run once, never again)

If you haven't created the `app_version` table yet, run this:

```sql
-- Create the table
CREATE TABLE app_version (
  id             INT PRIMARY KEY DEFAULT 1,
  latest_version TEXT NOT NULL,
  release_notes  TEXT NOT NULL DEFAULT '',
  download_url   TEXT NOT NULL DEFAULT '',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- Seed the first row
INSERT INTO app_version (id, latest_version, release_notes, download_url)
VALUES (1, '0.1.0', 'الإصدار الأول', '');

-- Enable Row Level Security and allow public read
ALTER TABLE app_version ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to everyone"
ON app_version FOR SELECT
USING (true);
```

If the table already exists but is missing the `download_url` column, add it with:

```sql
ALTER TABLE app_version
ADD COLUMN download_url TEXT NOT NULL DEFAULT '';
```

---

## Step 6 — Test End-to-End

On a device with the **old** version installed:

- [ ] Open app → Profile screen → scroll to bottom
- [ ] Tap **التحقق من التحديثات**
- [ ] Update dialog appears with version info and release notes
- [ ] **"تحديث الآن"** button is visible (only if `download_url` is set)
- [ ] Tap it — progress bar fills with live % percentage
- [ ] Android installer launches automatically
- [ ] Install → app opens on new version
- [ ] Tap check again → snackbar says "أنت تستخدم أحدث إصدار (0.1.1) ✓"

---

## What the User Sees

| State | UI |
|---|---|
| No update available | Snackbar: "أنت تستخدم أحدث إصدار (X.X.X) ✓" |
| Update available, no download link | Dialog with "لاحقاً" only |
| Update available, with download link | Dialog with "لاحقاً" and "تحديث الآن" |
| Downloading | Progress dialog: animated bar + live % + "إلغاء" |
| Installing | Progress bar indeterminate + "يرجى الانتظار..." |
| Download failed | Error box + "إعادة المحاولة" button |

---

## Quick Reference — What to Do Every Release

> [!IMPORTANT]
> All three steps are required. Skipping any one of them will break the update flow.

| # | What | Where | Timing |
|---|------|--------|--------|
| 1 | Bump `version:` in `pubspec.yaml` | Local code | Before building |
| 2 | Bump `kAppVersion` in `update_checker_service.dart` | Local code | Before building |
| 3 | Run `UPDATE app_version SET ...` with new version + notes + URL | Supabase SQL Editor | After uploading to GitHub |

---

## Version History (Keep Updated)

| Version | Build | Date       | Type    | Notes |
|---------|-------|------------|---------|-------|
| 0.1.0   | 1     | 2026-07-23 | Initial | First release |

---

## Troubleshooting

### No update dialog despite SQL update

- Run `SELECT * FROM app_version;` and verify `latest_version` is higher than installed
- Ensure `kAppVersion` in the installed APK is the old value (i.e. you haven't accidentally shipped the new constant)
- Check device internet connection

### "تعذّر التحقق من التحديثات" snackbar

- Device is offline
- Supabase free tier project is paused — resume it in the dashboard
- RLS policy missing — recreate it:

```sql
CREATE POLICY "Allow read access to everyone"
ON app_version FOR SELECT USING (true);
```

### "تحديث الآن" button doesn't appear

- `download_url` is empty in the Supabase row — run the UPDATE with the GitHub link

### Download starts but install doesn't trigger

- Check that `REQUEST_INSTALL_PACKAGES` is in `AndroidManifest.xml`
- On Android 8+, the user may need to grant "Install unknown apps" permission for this app in system settings
- The device may prompt with: *"Allow from this source"* — user must tap Allow

### Progress bar gets stuck at 100% / install never opens

- The APK file might be corrupted — re-download the URL in a browser and check file size
- The download might have finished but `open_filex` failed — check logcat for `[UpdateChecker]` tag

---

## File Reference

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Build version (versionCode + versionName) |
| `lib/services/update_checker_service.dart` | `kAppVersion` constant + Supabase fetch |
| `lib/widgets/update_check_tile.dart` | Check tile + download progress + installer trigger |
| `lib/screens/profile_screen.dart` | Hosts the tile |
| `android/app/src/main/AndroidManifest.xml` | `REQUEST_INSTALL_PACKAGES` + FileProvider |
| `android/app/src/main/res/xml/file_paths.xml` | FileProvider paths for APK sharing |
| Supabase `app_version` table | `latest_version`, `release_notes`, `download_url` |
