// Pure, testable auth routing logic.
enum AuthAction {
  noAction,
  denyAccess,
  routeAdmin,
  routeFarmNew,
  routeFarmPending,
  routeFarmVerified,
  routeCustomer,
  routeRider,
}

AuthAction determineAuthAction(Map<String, dynamic>? profileData, String selectedUiRole) {
  if (profileData == null) return AuthAction.noAction;

  final dbRole = (profileData['role'] ?? '') as String;

  if (dbRole.isEmpty) return AuthAction.noAction;

  if (dbRole != selectedUiRole) return AuthAction.denyAccess;

  switch (dbRole) {
    case 'Super Admin':
      return AuthAction.routeAdmin;
    case 'Farm Owner':
      final status = (profileData['status'] ?? 'new') as String;
      if (status == 'new') return AuthAction.routeFarmNew;
      if (status == 'pending') return AuthAction.routeFarmPending;
      if (status == 'verified') return AuthAction.routeFarmVerified;
      return AuthAction.noAction;
    case 'Customer':
      return AuthAction.routeCustomer;
    case 'Delivery Rider':
      return AuthAction.routeRider;
    default:
      return AuthAction.noAction;
  }
}
 
