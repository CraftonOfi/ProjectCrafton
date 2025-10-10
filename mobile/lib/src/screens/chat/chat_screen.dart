import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
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
      // lazy load (respaldo, normalmente se dispara en _ensureMessagesListener)
      ref.read(messagesProvider(counterpartId).notifier).load(page: 1);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: counterpartId == null
          ? _buildEmptyThreads(threads)
          : Column(
              children: [
                Expanded(
                    child: _buildMessagesList(
                        messagesState?.messages ?? [], me?.id ?? 0)),
                _buildComposer(counterpartId),
              ],
            ),
    );
  }

  Widget _buildEmptyThreads(ThreadsState threads) {
    if (threads.loading)
      return const Center(child: CircularProgressIndicator());
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
              color: isMine ? const Color(0xFF2563EB) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  m.body,
                  style:
                      TextStyle(color: isMine ? Colors.white : Colors.black87),
                ),
                if (m.attachments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: m.attachments
                        .map((a) => _AttachmentChip(url: a.url, type: a.type))
                        .toList(),
                  )
                ],
                const SizedBox(height: 2),
                Text(
                  Formatters.shortDateTime(m.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: isMine
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black54),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(int counterpartId) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF2563EB),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _send(counterpartId),
              ),
            )
          ],
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
}

class _AttachmentChip extends StatelessWidget {
  final String url;
  final String? type;
  const _AttachmentChip({required this.url, this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
