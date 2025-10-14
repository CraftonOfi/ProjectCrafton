import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/async_state_view.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/format.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int? counterpartId; // optional; when null, will use first thread
  const ChatScreen({super.key, this.counterpartId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  int? _listenedCounterpartId;
  final _scrollController = ScrollController();
  bool _scheduledInitialLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(threadsProvider.notifier).load();
      // Escuchar cambios en threads para establecer listener de mensajes
      ref.listen<ThreadsState>(threadsProvider, (prev, next) {
        _ensureMessagesListener();
      });
      _ensureMessagesListener();
      _scrollController.addListener(() {
        final threads = ref.read(threadsProvider);
        final counterpartId = widget.counterpartId ??
            (threads.threads.isNotEmpty ? threads.threads.first.id : null);
        if (counterpartId == null) return;
        final state = ref.read(messagesProvider(counterpartId));
        if (_scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 24 &&
            !state.loading &&
            state.page < state.pages) {
          ref
              .read(messagesProvider(counterpartId).notifier)
              .load(page: state.page + 1);
        }
      });
    });
  }

  void _ensureMessagesListener() {
    final threads = ref.read(threadsProvider);
    final resolvedId = widget.counterpartId ??
        (threads.threads.isNotEmpty ? threads.threads.first.id : null);
    if (resolvedId == null) return;
    if (_listenedCounterpartId == resolvedId) return;
    _listenedCounterpartId = resolvedId;

    // Listener para marcar como leídos los mensajes entrantes
    ref.listen<MessagesState>(messagesProvider(resolvedId), (prev, next) async {
      final myId = ref.read(currentUserProvider)?.id;
      if (myId == null) return;
      final unreadIncoming =
          next.messages.where((m) => m.toUserId == myId && !m.read);
      for (final m in unreadIncoming) {
        try {
          await ref.read(chatServiceProvider).markRead(m.id);
        } catch (_) {}
      }
      // Al marcar como leídos, resetea contador en lista de hilos
      final anyUnread = next.messages.any((m) => m.toUserId == myId && !m.read);
      if (!anyUnread) {
        ref.read(threadsProvider.notifier).setUnread(resolvedId, 0);
      }
    });

    // Trigger carga inicial si es necesario
    final messagesState = ref.read(messagesProvider(resolvedId));
    if (!messagesState.loading && messagesState.messages.isEmpty) {
      ref.read(messagesProvider(resolvedId).notifier).load(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final threads = ref.watch(threadsProvider);
    final counterpartId = widget.counterpartId ??
        (threads.threads.isNotEmpty ? threads.threads.first.id : null);
    final messagesState = counterpartId == null
        ? null
        : ref.watch(messagesProvider(counterpartId));
    if (counterpartId != null && (messagesState?.messages.isEmpty ?? true)) {
      // Evitar disparar carga durante build; programar post-frame una sola vez
      if (!_scheduledInitialLoad) {
        _scheduledInitialLoad = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(messagesProvider(counterpartId).notifier)
              .load(page: 1)
              .whenComplete(() => _scheduledInitialLoad = false);
        });
      }
    }

    // Resolver nombre del contacto para el título
    String titleText = 'Chat';
    String? initial;
    if (counterpartId != null) {
      ThreadSummary? cp;
      for (final t in threads.threads) {
        if (t.id == counterpartId) {
          cp = t;
          break;
        }
      }
      if (cp != null) {
        titleText = (cp.name.isNotEmpty ? cp.name : cp.email);
        initial = (cp.name.isNotEmpty
                ? cp.name[0]
                : (cp.email.isNotEmpty ? cp.email[0] : '?'))
            .toUpperCase();
      }
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.15),
              child: initial != null
                  ? Text(initial,
                      style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700))
                  : const Icon(Icons.person,
                      color: Color(0xFF2563EB), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              titleText,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: counterpartId == null
          ? _buildEmptyThreads(threads)
          : Column(
              children: [
                Expanded(
                  child: _buildMessagesArea(
                    counterpartId: counterpartId,
                    state: messagesState,
                    myId: me?.id ?? 0,
                  ),
                ),
                _buildComposer(counterpartId),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildEmptyThreads(ThreadsState threads) {
    if (threads.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(threads.error ??
            'No hay conversaciones aún. Envía un mensaje para iniciar soporte.'),
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages, int myId) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (ctx, idx) {
        final i = messages.length - 1 - idx;
        final m = messages[i];
        final isMine = m.fromUserId == myId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFF2563EB)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1F2937)
                      : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: BoxConstraints(
              // Limitar ancho para que respiren las burbujas
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  m.body,
                  style: TextStyle(
                      color: isMine
                          ? Colors.white
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87)),
                ),
                if (m.attachments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: m.attachments
                        .map((a) {
                          final svc = ref.read(chatServiceProvider);
                          final resolved = svc.resolveUrl(a.url);
                          return _AttachmentChip(url: resolved, type: a.type);
                        })
                        .toList()
                        .toList(),
                  )
                ],
                const SizedBox(height: 2),
                Text(
                  Formatters.shortDateTime(m.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.white.withOpacity(0.85)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesArea({
    required int counterpartId,
    required MessagesState? state,
    required int myId,
  }) {
    if (state == null || (state.loading && state.messages.isEmpty)) {
      return _buildMessagesShimmer();
    }
    if (state.error != null && state.messages.isEmpty) {
      return AsyncStateView(
        loading: false,
        error: state.error,
        onRetry: () =>
            ref.read(messagesProvider(counterpartId).notifier).load(page: 1),
        child: const SizedBox.shrink(),
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(messagesProvider(counterpartId).notifier).load(page: 1),
      child: _buildMessagesList(state.messages, myId),
    );
  }

  Widget _buildMessagesShimmer() {
    // Placeholders simples (sin dependencia externa) para simular shimmer
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: 10,
      itemBuilder: (context, index) {
        final isMine = index % 2 == 0;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 280),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedOpacity(
              opacity: 0.6,
              duration: const Duration(milliseconds: 800),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 160 + (index % 3) * 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(int counterpartId) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF111827)
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              if (Theme.of(context).brightness != Brightness.dark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Adjuntar',
                icon: Icon(
                  Icons.attach_file,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
                onPressed: () => _pickAndAttach(counterpartId),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(counterpartId),
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 40,
                width: 40,
                child: ElevatedButton(
                  onPressed: () => _send(counterpartId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(int counterpartId) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(messagesProvider(counterpartId).notifier).send(text);
  }

  Future<void> _pickAndAttach(int counterpartId) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: true,
      );
      if (res == null || res.files.first.bytes == null) return;
      final bytes = res.files.first.bytes!;
      // Re-encode imagen para limpieza y compresión
      final processed = await _reencodeJpeg(bytes);
      final uploaded = await ref.read(chatServiceProvider).uploadAttachment(
            processed,
            filename: 'attachment.jpg',
            mimeType: 'image/jpeg',
          );
      final url = uploaded['url'] as String;
      await ref
          .read(messagesProvider(counterpartId).notifier)
          .sendWithAttachments(
        _controller.text.trim().isEmpty ? '(adjunto)' : _controller.text.trim(),
        [MessageAttachment(url: url, type: 'image/jpeg')],
      );
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adjuntando archivo')),
      );
    }
  }

  Future<List<int>> _reencodeJpeg(List<int> data) async {
    final decoded = img.decodeImage(Uint8List.fromList(data));
    if (decoded == null) return data;
    final resized = img.copyResize(decoded, width: 1600, height: 1600);
    return img.encodeJpg(resized, quality: 82);
  }
}

class _AttachmentChip extends StatelessWidget {
  final String url;
  final String? type;
  const _AttachmentChip({required this.url, this.type});

  @override
  Widget build(BuildContext context) {
    final isImage = (type ?? '').startsWith('image');
    final child = isImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 180,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FilePill(url: url),
            ),
          )
        : _FilePill(url: url);
    return GestureDetector(
      onTap: () => _showPreview(context, url, isImage: isImage),
      child: child,
    );
  }
}

class _FilePill extends StatelessWidget {
  final String url;
  const _FilePill({required this.url});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              url.split('/').last,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// Viewer in-app con animación (Hero + Dialog transparente)
void _showPreview(BuildContext context, String url, {bool isImage = true}) {
  if (!isImage) {
    // para archivos no imagen, intentamos abrir igualmente en-app vía navegador
    final uri = Uri.parse(url);
    launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    return;
  }
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim1, anim2) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 16,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}
