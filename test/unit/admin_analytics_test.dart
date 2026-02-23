import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dairy_nova_app/admin_analytics_servics.dart';

void main() {
  test('totalRevenueStream computes sum of delivered orders', () async {
    final fake = FakeFirebaseFirestore();
    AdminAnalytics.setTestDb(fake);

    await fake.collection('orders').add({'status': 'Delivered', 'totalAmount': 100});
    await fake.collection('orders').add({'status': 'Pending', 'totalAmount': 200});
    await fake.collection('orders').add({'status': 'Delivered', 'totalAmount': 50});

    final total = await AdminAnalytics.totalRevenueStream.first;
    expect(total, 150.0);
  });

  test('verifiedFarmsCount counts verified farms', () async {
    final fake = FakeFirebaseFirestore();
    AdminAnalytics.setTestDb(fake);

    await fake.collection('farms').add({'status': 'verified'});
    await fake.collection('farms').add({'status': 'pending'});
    await fake.collection('farms').add({'status': 'verified'});

    final count = await AdminAnalytics.verifiedFarmsCount.first;
    expect(count, 2);
  });

  test('customerCount counts users with role Customer', () async {
    final fake = FakeFirebaseFirestore();
    AdminAnalytics.setTestDb(fake);

    await fake.collection('users').add({'role': 'Customer'});
    await fake.collection('users').add({'role': 'Customer'});
    await fake.collection('users').add({'role': 'Farm Owner'});

    final count = await AdminAnalytics.customerCount.first;
    expect(count, 2);
  });
}
