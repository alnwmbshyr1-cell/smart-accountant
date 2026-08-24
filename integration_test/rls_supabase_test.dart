import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const runRlsTests = bool.fromEnvironment('RUN_RLS_TESTS', defaultValue: false);
const supabaseUrl = String.fromEnvironment('RLS_SUPABASE_URL');
const publishableKey = String.fromEnvironment('RLS_SUPABASE_PUBLISHABLE_KEY');
const emailA = String.fromEnvironment('RLS_TEST_EMAIL_A');
const passwordA = String.fromEnvironment('RLS_TEST_PASSWORD_A');
const emailB = String.fromEnvironment('RLS_TEST_EMAIL_B');
const passwordB = String.fromEnvironment('RLS_TEST_PASSWORD_B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RLS يمنع المستخدم الثاني من قراءة أو تعديل سجل الأول', (tester) async {
    if (!runRlsTests) return;
    await Supabase.initialize(url: supabaseUrl, publishableKey: publishableKey);
    final client = Supabase.instance.client;

    await client.auth.signInWithPassword(email: emailA, password: passwordA);
    final userA = client.auth.currentUser!;
    final localId = DateTime.now().microsecondsSinceEpoch;
    await client.from('animals').insert({
      'owner_id': userA.id,
      'local_id': localId,
      'number': 'TEST-$localId',
      'tag_color': 'أخضر',
      'animal_type': 'نجدي',
      'gender': 'ذكر',
    });

    await client.auth.signOut();
    await client.auth.signInWithPassword(email: emailB, password: passwordB);
    final rowsForB = await client.from('animals').select('local_id').eq('local_id', localId);
    expect(rowsForB, isEmpty);

    final updateResult = await client.from('animals').update({'number': 'FORBIDDEN'}).eq('local_id', localId);
    expect(updateResult, isA<List>());

    await client.auth.signOut();
    await client.auth.signInWithPassword(email: emailA, password: passwordA);
    await client.from('animals').delete().eq('local_id', localId).eq('owner_id', userA.id);
    await client.auth.signOut();
  }, skip: !runRlsTests ? 'اختبار staging اختياري؛ فعّله RUN_RLS_TESTS=true مع حسابين تجريبيين.' : false);
}
