import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'uid_test',
        email: 'test@gmail.com',
      ),
    );
  });

  test("User should sign in", () async {
    final userCredential = await mockAuth.signInWithEmailAndPassword(
      email: "test@gmail.com",
      password: "123456",
    );

    expect(userCredential.user, isNotNull);
    expect(userCredential.user!.email, "test@gmail.com");
  });

  test("User should sign out", () async {
    await mockAuth.signOut();

    expect(mockAuth.currentUser, isNull);
  });
}
