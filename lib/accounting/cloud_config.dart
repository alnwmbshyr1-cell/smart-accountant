import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration helper. Mobile clients must use only a publishable/anon
/// key; authorization is enforced by PostgreSQL RLS, never by client-side checks alone.
class CloudConfig {
  const CloudConfig._();
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get configured => url.startsWith('https://') && publishableKey.isNotEmpty;

  static Future<SupabaseClient?> initialize() async {
    if (!configured) return null;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    return Supabase.instance.client;
  }
}
