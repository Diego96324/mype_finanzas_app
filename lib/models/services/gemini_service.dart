import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Modelo para representar un mensaje en el chat
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      content: map['content'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      isError: map['isError'] ?? false,
    );
  }
}

/// Servicio para interactuar con la API de Gemini
class GeminiService {
  // Singleton pattern
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  // ⚠️ IMPORTANTE: Para producción, considera mover esta Key a un archivo .env o usar --dart-define
  static const String _apiKey = 'AIzaSyB18roJrEJFUr5lEiAvWBzMMMMAwSRjEUc';

  // Endpoint de la API de Gemini (Usando versión 2.0 Flash)
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // Contexto del sistema para el asistente
  static const String _systemPrompt = '''
Eres un asistente virtual amigable y profesional de Numeria, una aplicación de gestión financiera para microempresas peruanas.

Tu rol es ayudar a los usuarios con:
- Dudas sobre cómo usar la aplicación
- Explicar funcionalidades de registro de ingresos y egresos
- Guiar en la gestión de categorías y subcategorías
- Explicar el sistema de presupuestos y alertas
- Ayudar con la interpretación de reportes y análisis disponibles en la app
- Resolver problemas técnicos comunes
- Explicar el sistema de gamificación y recompensas
 - Resumir información financiera en respuestas concisas
 
Características de la app que debes conocer:
- Registro de transacciones (ingresos y egresos)
- Múltiples cuentas financieras
- Categorías y subcategorías personalizables
- Sistema de presupuestos por categoría
- Alertas cuando se supera el presupuesto
- Reportes y análisis financiero
- Gamificación con retos y recompensas
- Respaldo de datos

Responde siempre en español, de forma clara, concisa y amigable.
Si no conoces la respuesta exacta, sugiere contactar al soporte técnico.
Usa emojis ocasionalmente para hacer la conversación más amigable.
''';

  /// Envía un mensaje a Gemini y obtiene la respuesta
  Future<String> sendMessage(String userMessage, List<ChatMessage> chatHistory) async {
    try {
      // Construir el historial de conversación para el contexto
      final List<Map<String, dynamic>> contents = [];

      // Agregar el contexto del sistema como primer mensaje
      contents.add({
        'role': 'user',
        'parts': [{'text': 'Contexto del sistema: $_systemPrompt'}]
      });

      // Respuesta pre-establecida para reforzar el rol
      contents.add({
        'role': 'model',
        'parts': [{'text': 'Entendido. Soy el asistente de MYPE Finanzas y estoy listo para ayudarte con cualquier consulta sobre la aplicación. ¿En qué puedo ayudarte hoy? 😊'}]
      });

      // Agregar historial de chat (limitado a los últimos 10 mensajes para no exceder límites de tokens)
      final recentHistory = chatHistory.length > 10
          ? chatHistory.sublist(chatHistory.length - 10)
          : chatHistory;

      for (final message in recentHistory) {
        contents.add({
          'role': message.isUser ? 'user' : 'model',
          'parts': [{'text': message.content}]
        });
      }

      // Agregar el mensaje actual del usuario
      contents.add({
        'role': 'user',
        'parts': [{'text': userMessage}]
      });

      // Hacer la petición a la API
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          // Configuraciones de seguridad relajadas para evitar falsos positivos en consultas financieras
          'safetySettings': [
            { 'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE' },
            { 'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE' },
            { 'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE' },
            { 'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE' },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extraer el texto de la respuesta
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] ??
              'Lo siento, no pude generar una respuesta.';
        } else {
          debugPrint('⚠️ [GeminiService] Respuesta inesperada: $data');
          return 'Lo siento, hubo un problema al procesar tu consulta. Por favor, intenta de nuevo.';
        }
      } else {
        debugPrint('⚠️ [GeminiService] Error HTTP ${response.statusCode}: ${response.body}');

        // Manejar errores específicos para dar feedback útil al usuario
        if (response.statusCode == 400) {
          return 'No entendí bien la solicitud. ¿Podrías reformular tu pregunta?';
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          return 'Error de permisos con el asistente. Contacta a soporte.';
        } else if (response.statusCode == 429) {
          return 'El asistente está recibiendo muchas consultas. Intenta en unos segundos.';
        } else if (response.statusCode >= 500) {
          return 'El asistente está durmiendo (error del servidor). Intenta más tarde.';
        }

        return 'Error de conexión. Verifica tu internet.';
      }
    } catch (e) {
      debugPrint('⚠️ [GeminiService] Exception: $e');
      return 'No pude conectarme. Por favor verifica tu conexión a internet.';
    }
  }

  /// Obtiene sugerencias de preguntas frecuentes para mostrar en la UI
  List<String> getQuickSuggestions() {
    return [
      '¿Cómo registro una transacción?',
      '¿Cómo creo un presupuesto?',
      '¿Cómo veo mis reportes?',
      '¿Cómo funciona la gamificación?',
      '¿Cómo hago un respaldo?',
      '¿Cómo agrego una categoría?',
    ];
  }
}