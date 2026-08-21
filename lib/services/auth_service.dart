// lib/services/auth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const String googleServerClientId =
      '989099900816-4hbq8amala6g74aa4gooogu46rnagv96.apps.googleusercontent.com';

  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: googleServerClientId,
    scopes: ['email', 'profile'],
  );

  UserProfile? _currentProfile;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated =>
      currentUser != null && currentUser!.isAnonymous == false;

  /// Initializes auth listener and loads profile if already logged in
  Future<void> initialize() async {
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
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with native Google Account Sheet
  Future<UserProfile?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Trigger native Google Sign-in flow
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in modal
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // 2. Obtain tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: No ID token returned.');
      }

      // 3. Exchange tokens with Supabase Auth
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
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
        _currentProfile = UserProfile.fromMap(res);
        notifyListeners();
        return _currentProfile;
      } else {
        // Create profile if not yet created
        _currentProfile = await _fetchOrBootstrapProfile(user);
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
        updates['username'] = username.trim();
      }
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updates['avatar_url'] = avatarUrl;
      }

      await _supabase.from('profiles').update(updates).eq('id', user.id);

      if (username != null) await ProfileService.saveProfileName(username);
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
      debugPrint('[AuthService] recordGameResult RPC failed, falling back to direct update: $e');
      if (_currentProfile != null) {
        final currentXp = _currentProfile!.xp + xpGain;
        final newLevel = UserProfile.calculateLevel(currentXp);
        await _supabase.from('profiles').update({
          'xp': currentXp,
          'level': newLevel,
          'games_played': _currentProfile!.gamesPlayed + 1,
          'games_won': _currentProfile!.gamesWon + (won ? 1 : 0),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
        await refreshProfile();
      }
    }
  }

  Future<UserProfile> _fetchOrBootstrapProfile(User user, [GoogleSignInAccount? googleUser]) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return UserProfile.fromMap(existing);
      }

      final fallbackName = googleUser?.displayName ??
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'Player';

      final fallbackAvatar = googleUser?.photoUrl ??
          user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          'preset:king';

      final newProfileMap = {
        'id': user.id,
        'email': user.email ?? '',
        'username': fallbackName,
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
        username: googleUser?.displayName ?? user.email?.split('@').first ?? 'Player',
        avatarUrl: googleUser?.photoUrl ?? 'preset:king',
      );
    }
  }
}
