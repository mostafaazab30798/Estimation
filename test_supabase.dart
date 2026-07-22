import 'package:supabase/supabase.dart';
import 'dart:math';

void main() async {
  final hostClient = SupabaseClient(
    'https://eqmkbfxerxqihforsgvx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  final guestClient = SupabaseClient(
    'https://eqmkbfxerxqihforsgvx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  try {
    print('1. Signing in Host & Guest anonymously...');
    await hostClient.auth.signInAnonymously();
    await guestClient.auth.signInAnonymously();
    print('Host ID: ${hostClient.auth.currentUser!.id}');
    print('Guest ID: ${guestClient.auth.currentUser!.id}');

    // Generate room code
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final roomCode = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    print('\n2. Host creating room with code: $roomCode');

    final createResponse = await hostClient.rpc('create_game_room', params: {
      'p_room_code': roomCode,
      'p_player_name': 'TestHost',
      'p_host_ip': '127.0.0.1',
      'p_ws_port': 4567,
    });
    print('Create Room Response: $createResponse');
    final roomId = createResponse['room_id'];

    print('\n3. Guest Attempting to JOIN the room using RPC...');
    try {
      final joinResponse = await guestClient.rpc('join_game_room', params: {
        'p_room_code': roomCode,
        'p_player_name': 'TestGuest',
      });
      print('Join Room Response: $joinResponse');
    } catch (e) {
      print('Failed to join room: $e');
    }

    print('\n4. Cleaning up (cancelling room)...');
    await hostClient.from('game_rooms').update({'status': 'cancelled'}).eq('id', roomId);
    print('Cleanup done.');

  } catch (e, st) {
    print('Error: $e\n$st');
  }
}
