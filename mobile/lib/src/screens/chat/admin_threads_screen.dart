import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

class AdminThreadsScreen extends ConsumerStatefulWidget {
  const AdminThreadsScreen({super.key});
  @override
  ConsumerState<AdminThreadsScreen> createState() => _AdminThreadsScreenState();
}

class _AdminThreadsScreenState extends ConsumerState<AdminThreadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(threadsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(threadsProvider.notifier).load(),
        child: state.loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) => const _ThreadPlaceholder(),
              )
            : (state.error != null)
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.sms_failed_outlined,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('No se pudieron cargar los mensajes',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(state.error!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () =>
                                  ref.read(threadsProvider.notifier).load(),
                              child: const Text('Reintentar'),
                            )
                          ],
                        ),
                      )
                    ],
                  )
                : (state.threads.isEmpty)
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          _EmptyThreads(),
                        ],
                      )
                    : ListView.separated(
                        itemCount: state.threads.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final t = state.threads[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      const Color(0xFF2563EB).withOpacity(0.15),
                                  child: Text(
                                    (t.name.isNotEmpty
                                            ? t.name[0]
                                            : (t.email.isNotEmpty
                                                ? t.email[0]
                                                : '?'))
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name.isNotEmpty ? t.name : t.email,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      _ThreadPreviewLine(t: t),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatShortDate(t.lastMessageAt),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.grey),
                                  ],
                                )
                              ],
                            ),
                          )._asTap(() {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ChatScreen(counterpartId: t.id),
                            ));
                          });
                        },
                      ),
      ),
    );
  }
}

extension on Widget {
  Widget _asTap(VoidCallback onTap) => InkWell(onTap: onTap, child: this);
}

String _formatShortDate(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  if (sameDay) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
}

class _ThreadPlaceholder extends StatelessWidget {
  const _ThreadPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF374151)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: double.infinity, height: 14),
          SizedBox(height: 8),
          _ShimmerBox(width: 140, height: 12),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _EmptyThreads extends StatelessWidget {
  const _EmptyThreads();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.forum_outlined, size: 72, color: Colors.grey),
        const SizedBox(height: 12),
        Text('Mensajes',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Aún no hay conversaciones. Aquí verás los mensajes de tus usuarios.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}

class _ThreadPreviewLine extends StatelessWidget {
  final ThreadSummary t;
  const _ThreadPreviewLine({required this.t});
  @override
  Widget build(BuildContext context) {
    const color = Colors.grey;
    final isOut = t.lastMessageDirection == 'out';
    final prefixIcon = isOut ? Icons.north_east : Icons.south_west;
    String statusTick;
    switch (t.lastMessageStatus) {
      case 'read':
        statusTick = '✓✓';
        break;
      case 'sent':
        statusTick = '✓';
        break;
      case 'received':
        statusTick = '↘';
        break;
      case 'unread':
        statusTick = '!';
        break;
      default:
        statusTick = '';
    }
    final previewText = (t.lastMessagePreview ?? '').isEmpty
        ? (t.unread > 0 ? 'No leídos: ${t.unread}' : 'Sin mensajes')
        : t.lastMessagePreview!;
    return Row(
      children: [
        Icon(prefixIcon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            previewText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: color, fontSize: 12),
          ),
        ),
        if (statusTick.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(statusTick, style: const TextStyle(color: color, fontSize: 12)),
        ]
      ],
    );
  }
}
