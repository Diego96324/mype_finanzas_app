import 'package:flutter_test/flutter_test.dart';
import 'package:mype_finanzas/data/repositories/auth_repo.dart';

void main() {
  group('AuthRepository.updateProfile clearAvatar', () {
    final repo = AuthRepository();

    test('should set avatar_uri to NULL when clearAvatar = true', () async {
      // 1) Register a temporary user
      final user = await repo.register(
        email: 'test.clear.avatar@example.com',
        password: 'password123',
        nombre: 'Test',
      );
      expect(user, isNotNull, reason: 'User must be created');
      final userId = user!.id!;

      // 2) Update profile to set an avatar value first
      final ok1 = await repo.updateProfile(
        userId: userId,
        avatarUri: '/tmp/some_avatar.jpg',
      );
      expect(ok1, isTrue);

      // Verify avatar was set
      final afterSet = await repo.getUserById(userId);
      expect(afterSet, isNotNull);
      expect(afterSet!.avatarUri, isNotNull);

      // 3) Now clear avatar using clearAvatar=true
      final ok2 = await repo.updateProfile(
        userId: userId,
        clearAvatar: true,
      );
      expect(ok2, isTrue);

      // 4) Read user again and expect avatarUri == null
      final afterClear = await repo.getUserById(userId);
      expect(afterClear, isNotNull);
      expect(afterClear!.avatarUri, isNull, reason: 'avatar_uri should be null after clearAvatar');
    });
  });
}

