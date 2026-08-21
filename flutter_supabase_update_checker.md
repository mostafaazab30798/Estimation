# Task: Add a Simple In-App Update Checker (Flutter + Supabase)

Implement a minimal version-check system. The app compares its own version against a "latest version" row stored in Supabase, and shows an update prompt inside the Profile screen if a newer version exists.

Keep everything as simple as possible — no forced update logic, no remote config, no complex versioning rules unless stated below.

---

## 1. Supabase Table

Create a table called `app_version` with a **single row** that always represents the latest published version.

```sql
create table app_version (
  id int primary key default 1,
  latest_version text not null,       -- e.g. '1.4.2'
  release_notes text not null default '',
  updated_at timestamptz not null default now(),
  constraint single_row check (id = 1)
);

-- seed the row
insert into app_version (id, latest_version, release_notes)
values (1, '1.0.0', 'Initial release');
```

Enable public read access (no auth needed to check version):

```sql
alter table app_version enable row level security;

create policy "Allow read access to everyone"
on app_version for select
using (true);
```

To publish a new version later, the developer just runs:

```sql
update app_version
set latest_version = '1.1.0',
    release_notes = 'Bug fixes and performance improvements',
    updated_at = now()
where id = 1;
```

That's the entire "admin" workflow — no admin UI needed.

---

## 2. Flutter Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  supabase_flutter: ^2.5.6
  package_info_plus: ^8.0.0
```

Assume `supabase_flutter` is already initialized in `main.dart` via `Supabase.initialize(...)`. If not, initialize it before `runApp()`.

---

## 3. Update Checker Service

Create `lib/services/update_checker_service.dart`:

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;

  UpdateInfo({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
  });
}

class UpdateCheckerService {
  final _client = Supabase.instance.client;

  Future<UpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // from pubspec version

    final response = await _client
        .from('app_version')
        .select('latest_version, release_notes')
        .eq('id', 1)
        .single();

    final latestVersion = response['latest_version'] as String;
    final releaseNotes = response['release_notes'] as String? ?? '';

    return UpdateInfo(
      updateAvailable: _isNewer(latestVersion, currentVersion),
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseNotes: releaseNotes,
    );
  }

  /// Simple semantic version comparison (major.minor.patch)
  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
```

Notes for the agent:
- `packageInfo.version` reads the app's version from `pubspec.yaml` (the `version: 1.0.0+1` field), so the app's actual version must be bumped there on each release too.
- Wrap the Supabase call in try/catch where it's used — don't let a failed check crash the Profile screen.

---

## 4. Profile Screen Integration

Add a small widget/section to the existing Profile screen that checks for updates and shows a simple dialog if one is available.

Create `lib/widgets/update_check_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/update_checker_service.dart';

class UpdateCheckTile extends StatelessWidget {
  const UpdateCheckTile({super.key});

  Future<void> _checkForUpdate(BuildContext context) async {
    final service = UpdateCheckerService();

    try {
      final info = await service.checkForUpdate();

      if (!context.mounted) return;

      if (info.updateAvailable) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
              'A new version (${info.latestVersion}) is available.\n\n'
              'What\'s new:\n${info.releaseNotes}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You\'re on the latest version.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check for updates.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: const Text('Check for Updates'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _checkForUpdate(context),
    );
  }
}
```

Then in the existing Profile screen file, add this tile somewhere sensible (e.g. near "About" / "Settings" items):

```dart
import '../widgets/update_check_tile.dart';

// inside the profile screen's build method, in the list of tiles/options:
const UpdateCheckTile(),
```

---

## 5. Optional (skip unless asked)

- Auto-check on app start instead of manual tap — only add if explicitly requested.
- "Open store" button linking to Play Store / App Store — only add if explicitly requested.
- Force-update / minimum-supported-version logic — only add if explicitly requested.

Do not add these unless the user asks — the goal is the simplest possible version-check flow.

---

## Summary of files to create/edit

1. `pubspec.yaml` — add `supabase_flutter`, `package_info_plus`
2. Supabase — create `app_version` table + RLS policy (SQL above)
3. `lib/services/update_checker_service.dart` — new file
4. `lib/widgets/update_check_tile.dart` — new file
5. Existing Profile screen file — add `UpdateCheckTile()` to the widget tree
