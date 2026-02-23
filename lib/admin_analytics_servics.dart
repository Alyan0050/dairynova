
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalytics {
  // Allows tests to inject a fake Firestore instance.
  static FirebaseFirestore? _testDb;

  static FirebaseFirestore get _db => _testDb ?? FirebaseFirestore.instance;

  /// Set a test Firestore instance (only for tests).
  static void setTestDb(FirebaseFirestore? firestore) => _testDb = firestore;

  // Stream for Total Revenue (Sum of all Delivered orders)
  static Stream<double> get totalRevenueStream => _db
      .collection('orders')
      .where('status', isEqualTo: 'Delivered')
      .snapshots()
      .map((snapshot) {
        double total = 0;
        for (var doc in snapshot.docs) {
          total += (doc['totalAmount'] ?? 0).toDouble();
        }
        return total;
      });

  // Stream for Count of Verified Farms
  static Stream<int> get verifiedFarmsCount => _db
      .collection('farms')
      .where('status', isEqualTo: 'verified')
      .snapshots()
      .map((snap) => snap.docs.length);

  // Stream for Total Customers
  static Stream<int> get customerCount => _db
      .collection('users')
      .where('role', isEqualTo: 'Customer')
      .snapshots()
      .map((snap) => snap.docs.length);
}