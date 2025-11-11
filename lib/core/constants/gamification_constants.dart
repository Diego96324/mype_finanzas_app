enum AchievementType { pointsBased, streakBased, eventBased }

class GamificationConstants {
  // Puntos por tipo de transacción (puedes ajustar según reglas de negocio)
  static const Map<String, int> pointsPerTransactionType = {
    'ingreso': 5,
    'egreso': 10,
    'transferencia': 2,
  };

  // Puntos por defecto si no hay regla específica
  static const int defaultPoints = 1;

  // Points needed per level step
  static const int pointsPerLevel = 500;

  // Estado de logros
  static const String achievementLocked = 'locked';
  static const String achievementInProgress = 'in_progress';
  static const String achievementUnlocked = 'unlocked';
}

