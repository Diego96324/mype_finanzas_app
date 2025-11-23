import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/services/gemini_service.dart';

/// Estado del asistente de FAQ
class FaqAssistantState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const FaqAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  FaqAssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return FaqAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier para manejar el estado del chat con Gemini
class FaqAssistantNotifier extends StateNotifier<FaqAssistantState> {
  final GeminiService _geminiService;

  FaqAssistantNotifier(this._geminiService) : super(const FaqAssistantState()) {
    // Agregar mensaje de bienvenida
    _addWelcomeMessage();
  }

  /// Registra un evento de copia para futuros analytics
  void handleCopy(ChatMessage message) {
    debugPrint('📋 [FaqAssistant] Mensaje copiado: ${message.content}');
  }

  /// Reintenta el envío de un mensaje según su origen
  Future<void> retryMessage(ChatMessage message) async {
    if (message.isUser) {
      debugPrint('🔄 [FaqAssistant] Reintentando mensaje del usuario');
      await sendMessage(message.content);
      return;
    }

    // Si es un mensaje de error del asistente, intenta reenviar el último mensaje válido del usuario
    final lastUserMessage = state.messages.lastWhere(
          (m) => m.isUser,
      orElse: () => ChatMessage(content: '', isUser: true),
    );

    if (lastUserMessage.content.isNotEmpty) {
      debugPrint('🔄 [FaqAssistant] Reintentando última consulta del usuario');
      await sendMessage(lastUserMessage.content);
    }
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      content: '¡Hola! 👋 Soy tu asistente virtual de Numeria.\n\n'
          'Estoy aquí para ayudarte con cualquier duda sobre la aplicación. '
          'Puedes preguntarme sobre:\n\n'
          '• Registro de transacciones\n'
          '• Gestión de categorías\n'
          '• Presupuestos y alertas\n'
          '• Reportes y análisis\n'
          '• Y mucho más...\n\n'
          '¿En qué puedo ayudarte hoy?',
      isUser: false,
    );

    state = state.copyWith(messages: [welcomeMessage]);
  }

  /// Envía un mensaje al asistente
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Agregar mensaje del usuario
    final userMessage = ChatMessage(
      content: message,
      isUser: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Obtener respuesta de Gemini
      final response = await _geminiService.sendMessage(
        message,
        state.messages.where((m) => !m.isError).toList(),
      );

      // Agregar respuesta del asistente
      final assistantMessage = ChatMessage(
        content: response,
        isUser: false,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );

      debugPrint('✅ [FaqAssistant] Mensaje enviado y respuesta recibida');
    } catch (e) {
      debugPrint('⚠️ [FaqAssistant] Error: $e');

      // Agregar mensaje de error
      final errorMessage = ChatMessage(
        content: 'Lo siento, ocurrió un error al procesar tu mensaje. '
            'Por favor, intenta de nuevo.',
        isUser: false,
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Limpia el historial de chat
  void clearChat() {
    state = const FaqAssistantState();
    _addWelcomeMessage();
    debugPrint('🗑️ [FaqAssistant] Chat limpiado');
  }

  /// Obtiene las sugerencias rápidas
  List<String> getQuickSuggestions() {
    return _geminiService.getQuickSuggestions();
  }
}

/// Provider del servicio de Gemini
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Provider del controlador del asistente FAQ
final faqAssistantProvider =
StateNotifierProvider<FaqAssistantNotifier, FaqAssistantState>((ref) {
  final geminiService = ref.watch(geminiServiceProvider);
  return FaqAssistantNotifier(geminiService);
});

/// Provider para las sugerencias rápidas
final quickSuggestionsProvider = Provider<List<String>>((ref) {
  final geminiService = ref.watch(geminiServiceProvider);
  return geminiService.getQuickSuggestions();
});