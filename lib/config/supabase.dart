import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://rqustqrxtomcinstjqzt.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxdXN0cXJ4dG9tY2luc3RqcXp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMjU2MDEsImV4cCI6MjA5MzkwMTYwMX0.oqCnrF5k_3ItoDdBLfgYWRjpSvpB7IyKRVuVTTGVZjU';

  // Table names
  static const String usersTable = 'resultwave_users';
  static const String backupsTable = 'resultwave_backup';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration backupTimeout = Duration(minutes: 2);
}
