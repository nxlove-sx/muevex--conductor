import 'package:muevex_conductor/core/supabase/supabase_client.dart' as db;
import 'package:muevex_conductor/data/models/app_notification_model.dart';

class NotificationsRepository {
  final _client = db.supabase;

  Future<List<AppNotification>> getMine(String userId) async {
    final res = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return res.map(AppNotification.fromMap).toList();
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  Future<void> notify(
    String userId, {
    required String type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
    });
  }
}