import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://eqmkbfxerxqihforsgvx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWtiZnhlcnhxaWhmb3JzZ3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNjQ0NTUsImV4cCI6MjA5OTY0MDQ1NX0.3F_n2TUVGTucW2DUWpv5YxqOtFkBQZaQJZKngL7gOx0',
  );

  try {
    print('Fetching all game rooms...');
    final response = await client.from('game_rooms').select();
    final rooms = response as List<dynamic>;
    
    if (rooms.isEmpty) {
      print('There are 0 rooms in the database. The table is completely empty!');
    } else {
      print('Found ${rooms.length} rooms:');
      for (final room in rooms) {
        print('- Code: ${room['room_code']}, Status: ${room['status']}, ID: ${room['id']}');
      }
    }
  } catch (e) {
    print('Error fetching rooms: $e');
  }
}
