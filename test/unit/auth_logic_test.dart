import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_nova_app/auth/auth_logic.dart';

void main() {
  test('returns noAction when profile is null', () {
    final action = determineAuthAction(null, 'Customer');
    expect(action, AuthAction.noAction);
  });

  test('customer routes to customer', () {
    final data = {'role': 'Customer'};
    final action = determineAuthAction(data, 'Customer');
    expect(action, AuthAction.routeCustomer);
  });

  test('farm owner with new status routes to register', () {
    final data = {'role': 'Farm Owner', 'status': 'new'};
    final action = determineAuthAction(data, 'Farm Owner');
    expect(action, AuthAction.routeFarmNew);
  });

  test('farm owner with pending status shows waiting', () {
    final data = {'role': 'Farm Owner', 'status': 'pending'};
    final action = determineAuthAction(data, 'Farm Owner');
    expect(action, AuthAction.routeFarmPending);
  });

  test('farm owner with verified status routes to dashboard', () {
    final data = {'role': 'Farm Owner', 'status': 'verified'};
    final action = determineAuthAction(data, 'Farm Owner');
    expect(action, AuthAction.routeFarmVerified);
  });

  test('super admin routes to admin dashboard', () {
    final data = {'role': 'Super Admin'};
    final action = determineAuthAction(data, 'Super Admin');
    expect(action, AuthAction.routeAdmin);
  });

  test('delivery rider routes to rider', () {
    final data = {'role': 'Delivery Rider'};
    final action = determineAuthAction(data, 'Delivery Rider');
    expect(action, AuthAction.routeRider);
  });

  test('mismatched role denies access', () {
    final data = {'role': 'Customer'};
    final action = determineAuthAction(data, 'Farm Owner');
    expect(action, AuthAction.denyAccess);
  });
}
