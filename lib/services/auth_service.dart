// lib/services/auth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/string_utils.dart';
import '../core/utils/display_name_validator.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const String googleServerClientId =
      '989099900816-4hbq8amala6g74aa4gooogu46rnagv96.apps.googleusercontent.com';

  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  UserProfile? _currentProfile;
  bool _isLoading = false;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated =>
      currentUser != null && currentUser!.isAnonymous == false;

  /// Initializes auth listener and loads profile if already logged in
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      try {
        await _googleSignIn.initialize(
          serverClientId: googleServerClientId,
        );
      } catch (e) {
        debugPrint('[AuthService] GoogleSignIn.initialize error: $e');
      }
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null && session.user.isAnonymous == false) {
        await refreshProfile();
      } else {
        _currentProfile = null;
        notifyListeners();
      }
    });

    if (isAuthenticated) {
      await refreshProfile();
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with native Google Account Sheet on Android/iOS, and Web OAuth on Web
  Future<UserProfile?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // Web: Use direct Supabase OAuth redirect to stay on the current origin
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Mobile (Android / iOS): Use native Google Account Bottom Sheet
      final googleUser = await _googleSignIn.authenticate();

      // Obtain tokens
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: No ID token returned.');
      }

      // Exchange tokens with Supabase Auth
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user != null) {
        // 4. Fetch or bootstrap profile
        final profile = await _fetchOrBootstrapProfile(user, googleUser);
        
        // 5. Sync profile name & avatar with local ProfileService for gameplay
        if (profile.username.isNotEmpty) {
          await ProfileService.saveProfileName(profile.username);
        }
        if (profile.avatarUrl.isNotEmpty) {
          await ProfileService.saveProfilePhoto(profile.avatarUrl);
        }

        _currentProfile = profile;
        _isLoading = false;
        notifyListeners();
        return profile;
      }
    } catch (e, stack) {
      debugPrint('[AuthService] signInWithGoogle error: $e\n$stack');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Signs out from Google and Supabase
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] Google signOut error: $e');
    }

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Supabase signOut error: $e');
    }

    _currentProfile = null;
    _isLoading = false;
    notifyListeners();

    // Re-sign in anonymously in background for RLS if needed
    try {
      await _supabase.auth.signInAnonymously();
    } catch (e) {
      debugPrint('[AuthService] Anonymous fallback error: $e');
    }
  }

  /// Fetches latest profile from `public.profiles`
  Future<UserProfile?> refreshProfile() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      _currentProfile = null;
      notifyListeners();
      return null;
    }

    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        final profile = UserProfile.fromMap(res);
        final formattedName = StringUtils.capitalizeWords(profile.username);
        if (formattedName != res['username'] && formattedName.isNotEmpty) {
          try {
            await _supabase.from('profiles').update({'username': formattedName}).eq('id', user.id);
          } catch (_) {}
        }
        _currentProfile = profile.copyWith(username: formattedName);
        if (_currentProfile!.username.isNotEmpty) {
          await ProfileService.saveProfileName(_currentProfile!.username);
        }
        notifyListeners();
        return _currentProfile;
      } else {
        // Create profile if not yet created
        _currentProfile = await _fetchOrBootstrapProfile(user);
        if (_currentProfile!.username.isNotEmpty) {
          await ProfileService.saveProfileName(_currentProfile!.username);
        }
        notifyListeners();
        return _currentProfile;
      }
    } catch (e) {
      debugPrint('[AuthService] refreshProfile error: $e');
      return _currentProfile;
    }
  }

  /// Updates profile metadata (username or avatar) in Supabase and local cache
  Future<bool> updateProfile({String? username, String? avatarUrl}) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      if (username != null) await ProfileService.saveProfileName(username);
      if (avatarUrl != null) await ProfileService.saveProfilePhoto(avatarUrl);
      return true;
    }

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (username != null && username.trim().isNotEmpty) {
        final formatted = StringUtils.capitalizeWords(username);
        final validationError = DisplayNameValidator.validate(formatted);
        if (validationError != null) {
          debugPrint('[AuthService] updateProfile validation: $validationError');
          return false;
        }
        updates['username'] = formatted;
        await ProfileService.saveProfileName(formatted);
      }
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updates['avatar_url'] = avatarUrl;
      }

      await _supabase.from('profiles').update(updates).eq('id', user.id);

      if (avatarUrl != null) await ProfileService.saveProfilePhoto(avatarUrl);

      await refreshProfile();
      return true;
    } catch (e) {
      debugPrint('[AuthService] updateProfile error: $e');
      return false;
    }
  }

  /// Increments player XP and game stats atomically via Supabase
  Future<void> recordGameResult({required bool won, int xpGain = 50}) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await _supabase.rpc('increment_player_stats', params: {
        'player_id': user.id,
        'xp_gain': xpGain,
        'won': won,
      });
      await refreshProfile();
    } catch (e) {
      // Competitive stats are server-only (Phase 1 W1.3); no client fallback.
      debugPrint('[AuthService] recordGameResult RPC failed: $e');
    }
  }

  /// Formats a name so each word starts with a capital letter (Title Case).
  static String capitalizeName(String name) => StringUtils.capitalizeWords(name);

  /// Deletes the authenticated account and all associated app data server-side.
  /// Call after Google re-authentication.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('يجب تسجيل الدخول لحذف الحساب.');
    }

    await _supabase.rpc('delete_user_account');
    _currentProfile = null;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _supabase.auth.signOut();
    } catch (_) {}

    try {
      await _supabase.auth.signInAnonymously();
    } catch (e) {
      debugPrint('[AuthService] Anonymous fallback after delete error: $e');
    }
  }

  Future<UserProfile> _fetchOrBootstrapProfile(User user, [GoogleSignInAccount? googleUser]) async {
    final rawName = googleUser?.displayName ??
        user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@').first.replaceAll(RegExp(r'[._]'), ' ') ??
        'Player';
    final formattedName = capitalizeName(rawName);

    final fallbackAvatar = googleUser?.photoUrl ??
        user.userMetadata?['avatar_url'] ??
        user.userMetadata?['picture'] ??
        'preset:king';

    // Do not insert anonymous users into public.profiles
    if (user.isAnonymous || (user.email == null || user.email!.isEmpty)) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        username: formattedName,
        avatarUrl: fallbackAvatar,
      );
    }

    try {
      final existing = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        final profile = UserProfile.fromMap(existing);
        final existingFormatted = capitalizeName(profile.username);
        if (existingFormatted != existing['username'] && existingFormatted.isNotEmpty) {
          try {
            await _supabase.from('profiles').update({'username': existingFormatted}).eq('id', user.id);
          } catch (_) {}
        }
        return profile.copyWith(username: existingFormatted);
      }

      final newProfileMap = {
        'id': user.id,
        'email': user.email ?? '',
        'username': formattedName,
        'avatar_url': fallbackAvatar,
        'xp': 0,
        'level': 1,
        'games_played': 0,
        'games_won': 0,
      };

      final inserted = await _supabase
          .from('profiles')
          .upsert(newProfileMap)
          .select()
          .single();

      return UserProfile.fromMap(inserted);
    } catch (e) {
      debugPrint('[AuthService] _fetchOrBootstrapProfile error: $e');
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        username: formattedName,
        avatarUrl: fallbackAvatar,
      );
    }
  }
}
