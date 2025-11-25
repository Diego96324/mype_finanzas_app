import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../models/services/gemini_service.dart';
import '../../controllers/support/faq_assistant_controller.dart';

class FaqAssistantView extends ConsumerStatefulWidget {
  const FaqAssistantView({super.key});

  @override
  ConsumerState<FaqAssistantView> createState() => _FaqAssistantViewState();
}

class _FaqAssistantViewState extends ConsumerState<FaqAssistantView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FlutterTts _tts = FlutterTts();

  // Mensaje seleccionado (tipo WhatsApp para mostrar acciones)
  ChatMessage? _selectedMessage;

  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _ttsEnabled = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.5);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    ref.read(faqAssistantProvider.notifier).sendMessage(message);
    _messageController.clear();
    _scrollToBottom();
  }

  void _sendQuickMessage(String message) {
    ref.read(faqAssistantProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  void _clearSelection() {
    setState(() => _selectedMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faqAssistantProvider);
    final suggestions = ref.watch(quickSuggestionsProvider);

    ref.listen(faqAssistantProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        if (next.messages.isNotEmpty) {
          final lastMessage = next.messages.last;
          HapticFeedback.lightImpact();
          if (!lastMessage.isUser) {
            _speakMessage(lastMessage.content);
          }
        }
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: _highContrast ? Colors.black : const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: _highContrast ? Colors.black : const Color(0xFF2D2D2D),
        elevation: 0,
        leading: _selectedMessage != null
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _clearSelection,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: _selectedMessage != null
            ? Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    '1 mensaje',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13BB67).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: Color(0xFF13BB67),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NumeriaBot',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'En línea',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF13BB67),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: _selectedMessage != null
            ? [
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  tooltip: 'Copiar',
                  onPressed: () {
                    if (_selectedMessage == null) return;
                    Clipboard.setData(ClipboardData(text: _selectedMessage!.content));
                    ref.read(faqAssistantProvider.notifier).handleCopy(_selectedMessage!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mensaje copiado'), duration: Duration(seconds: 1)),
                    );
                    _clearSelection();
                  },
                ),
                if (!_selectedMessage!.isUser || _selectedMessage!.isError)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Reintentar',
                    onPressed: () {
                      if (_selectedMessage == null) return;
                      ref.read(faqAssistantProvider.notifier).retryMessage(_selectedMessage!);
                      _clearSelection();
                    },
                  ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'font_up':
                        setState(() => _fontScale = (_fontScale + 0.1).clamp(0.8, 1.6));
                        break;
                      case 'font_down':
                        setState(() => _fontScale = (_fontScale - 0.1).clamp(0.8, 1.6));
                        break;
                      case 'contrast':
                        setState(() => _highContrast = !_highContrast);
                        break;
                      case 'tts':
                        setState(() => _ttsEnabled = !_ttsEnabled);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'font_up',
                      child: ListTile(
                        leading: Icon(Icons.text_increase),
                        title: Text('Aumentar fuente'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'font_down',
                      child: ListTile(
                        leading: Icon(Icons.text_decrease),
                        title: Text('Reducir fuente'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'contrast',
                      child: ListTile(
                        leading: Icon(
                          _highContrast ? Icons.contrast : Icons.contrast_outlined,
                        ),
                        title: const Text('Modo alto contraste'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tts',
                      child: ListTile(
                        leading: Icon(
                          _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                        ),
                        title: const Text('Leer respuestas (TTS)'),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Nuevo chat',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF2D2D2D),
                        title: const Text(
                          'Nuevo chat',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          '¿Deseas iniciar una nueva conversación? Se borrará el historial actual.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              ref.read(faqAssistantProvider.notifier).clearChat();
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF13BB67),
                            ),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: state.messages.length + (state.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.messages.length && state.isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(state.messages[index]);
              },
            ),
          ),
          if (state.messages.length <= 2 && !state.isLoading)
            _buildQuickSuggestions(suggestions),
          _buildInputField(state.isLoading),
        ],
      ),
    );
  }

  Future<void> _speakMessage(String message) async {
    if (!_ttsEnabled || message.isEmpty) return;
    await _tts.stop();
    await _tts.speak(message);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: _highContrast ? Colors.white70 : Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Inicia una conversación',
            style: TextStyle(
              fontSize: 16 * _fontScale,
              color: _highContrast ? Colors.white70 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isSelected = _selectedMessage == message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF13BB67).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color(0xFF13BB67),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(),
                  (LongPressGestureRecognizer instance) {
                    instance.onLongPress = () {
                      setState(() {
                        _selectedMessage = message;
                      });
                    };
                  },
                ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTap = () {
                      if (_selectedMessage != null) {
                        _clearSelection();
                      }
                    };
                  },
                ),
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85, // Un poco más ancho para Markdown
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF13BB67)
                      : message.isError
                      ? Colors.red.withValues(alpha: 0.2)
                      : _highContrast
                      ? Colors.grey[900]
                      : const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  // Resaltar si está seleccionado
                  border: isSelected ? Border.all(color: Colors.white24, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Usamos markdown_plus
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: message.content,
                      // Evito que el long-press seleccione el texto;
                      // el long-press selecciona la burbuja y salen las acciones arriba.
                      selectable: false,
                      onTapLink: (text, href, title) {
                        debugPrint('Link tocado: $href');
                      },
                      styleSheet: MarkdownStyleSheet(
                        // Párrafos
                        p: TextStyle(
                          fontSize: 14 * _fontScale,
                          height: 1.4,
                          color: isUser
                              ? Colors.white
                              : message.isError
                              ? Colors.red[300]
                              : Colors.white,
                        ),
                        // Negritas
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUser ? Colors.white : Colors.white,
                        ),
                        // Listas
                        listBullet: TextStyle(
                          color: isUser ? Colors.white : Colors.white,
                        ),
                        // Código en línea
                        code: TextStyle(
                          backgroundColor: Colors.black26,
                          color: Colors.orangeAccent,
                          fontFamily: 'monospace',
                          fontSize: 13 * _fontScale,
                        ),
                        // Bloques de código
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Tablas
                        tableBorder: TableBorder.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        tableHead: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        tableBody: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10 * _fontScale,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF13BB67).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF13BB67),
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF13BB67).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Color(0xFF13BB67),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _highContrast ? Colors.grey[900] : const Color(0xFF2D2D2D),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF13BB67).withValues(
              alpha: 0.3 + (0.7 * (1 - (value - value.floor()))),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }


  Widget _buildQuickSuggestions(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor:
                _highContrast ? Colors.grey[900] : const Color(0xFF2D2D2D),
                side: BorderSide(
                  color: const Color(0xFF13BB67).withValues(alpha: 0.5),
                ),
                label: Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 12 * _fontScale,
                    color: Colors.white70,
                  ),
                ),
                onPressed: () => _sendQuickMessage(suggestion),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputField(bool isLoading) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _highContrast ? Colors.black : const Color(0xFF2D2D2D),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _highContrast ? Colors.black : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                enabled: !isLoading,
                style: TextStyle(color: Colors.white, fontSize: 14 * _fontScale),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isLoading
                      ? 'Esperando respuesta...'
                      : 'Escribe tu mensaje...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14 * _fontScale,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.grey[600]
                  : const Color(0xFF13BB67),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}