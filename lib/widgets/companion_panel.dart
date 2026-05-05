import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/companion.dart';
import '../models/book_session.dart';
import '../services/companion_session_manager.dart';

class CompanionPanel extends StatefulWidget {
  /// Text the user has currently selected — pre-fills the input
  final String selectedText;
  final VoidCallback onClose;

  const CompanionPanel({
    super.key,
    required this.selectedText,
    required this.onClose,
  });

  @override
  State<CompanionPanel> createState() => _CompanionPanelState();
}

class _CompanionPanelState extends State<CompanionPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // Quick action being processed
  String? _activeAction;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll to bottom when new message arrives ─────────────────────────────
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

  // ── Send a plain message ──────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() => _activeAction = null);

    final manager = context.read<CompanionSessionManager>();
    await manager.sendMessage(
      text,
      highlightedPassage: widget.selectedText.isNotEmpty
          ? widget.selectedText
          : null,
    );
    _scrollToBottom();
  }

  // ── Quick action ──────────────────────────────────────────────────────────
  Future<void> _quickAction(String action) async {
    if (widget.selectedText.isEmpty) return;
    setState(() => _activeAction = action);

    final manager = context.read<CompanionSessionManager>();
    final prompt = switch (action) {
      'summarise' => 'Please summarise this passage.',
      'explain' => 'Please explain this passage in simple terms.',
      'concepts' => 'What are the key concepts in this passage?',
      _ => action,
    };

    await manager.sendMessageStreaming(
      prompt,
      highlightedPassage: widget.selectedText,
    );

    if (mounted) setState(() => _activeAction = null);
    _scrollToBottom();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<CompanionSessionManager>();
    final session = manager.session;
    if (session == null) return const SizedBox();

    final companion = session.companionConfig.type;
    final primaryColor = companion.primaryColor;
    final messages = session.recentHistory();

    // Scroll when messages update
    if (messages.isNotEmpty) _scrollToBottom();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [

          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(session, primaryColor, manager),

          // ── Selected text preview ────────────────────────────────────────
          if (widget.selectedText.isNotEmpty)
            _buildSelectedTextPreview(),

          // ── Quick actions ─────────────────────────────────────────────────
          if (widget.selectedText.isNotEmpty)
            _buildQuickActions(primaryColor),

          // ── Messages ─────────────────────────────────────────────────────
          Expanded(
            child: messages.isEmpty && !manager.isThinking
                ? _buildEmptyState(session, primaryColor)
                : _buildMessageList(messages, manager, primaryColor),
          ),

          // ── Input bar ────────────────────────────────────────────────────
          _buildInputBar(manager, primaryColor),

        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BookSession session, Color primaryColor,
      CompanionSessionManager manager) {
    final companion = session.companionConfig.type;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [

          // Companion avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                _companionEmoji(companion),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _companionName(companion),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.cream,
                ),
              ),
              Text(
                manager.isScanning
                    ? 'Scanning book...'
                    : session.hasBookContext
                    ? 'Knows this book'
                    : 'Ready to help',
                style: TextStyle(
                  fontSize: 11,
                  color: session.hasBookContext
                      ? primaryColor
                      : AppColors.muted,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Scanning indicator
          if (manager.isScanning)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: primaryColor,
                ),
              ),
            ),

          // Close
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.muted,
                size: 20,
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Selected text preview ─────────────────────────────────────────────────
  Widget _buildSelectedTextPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cream.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        '"${widget.selectedText.length > 160 ? '${widget.selectedText.substring(0, 160)}…' : widget.selectedText}"',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.cream.withValues(alpha: 0.55),
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _quickBtn('Summarise', 'summarise',
              Icons.compress_rounded, primaryColor),
          const SizedBox(width: 8),
          _quickBtn('Explain', 'explain',
              Icons.lightbulb_outline_rounded, primaryColor),
          const SizedBox(width: 8),
          _quickBtn('Concepts', 'concepts',
              Icons.tag_rounded, primaryColor),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, String action,
      IconData icon, Color color) {
    final isActive = _activeAction == action;
    return Expanded(
      child: GestureDetector(
        onTap: () => _quickAction(action),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.2)
                : AppColors.cream.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.5)
                  : AppColors.cream.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive ? color : AppColors.muted),
              const SizedBox(height: 3),
              Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isActive ? color : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(
      List<ChatMessage> messages,
      CompanionSessionManager manager,
      Color primaryColor,
      ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: messages.length + (manager.isThinking ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Thinking indicator at end
        if (i == messages.length) {
          return _buildThinkingBubble(primaryColor, manager.streamBuffer);
        }
        return _buildMessageBubble(messages[i], primaryColor);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, Color primaryColor) {
    final isUser = msg.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [

          // Companion avatar (left side)
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _companionEmoji(
                    context.read<CompanionSessionManager>()
                        .session?.companionConfig.type ??
                        CompanionType.sage,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [

                // Highlighted passage reference
                if (!isUser && msg.highlightedPassage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      '"${msg.highlightedPassage!.length > 80 ? '${msg.highlightedPassage!.substring(0, 80)}…' : msg.highlightedPassage}"',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? primaryColor.withValues(alpha: 0.15)
                        : AppColors.cream.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser
                          ? primaryColor.withValues(alpha: 0.25)
                          : AppColors.cream.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.cream.withValues(alpha: 0.9),
                      height: 1.6,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),

                // Out of book flag
                if (!isUser && msg.isOutOfBook) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 11,
                          color: AppColors.muted.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Drawing on knowledge beyond this book',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.muted.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],

                // Copy button for assistant messages
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.muted.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 36),

        ],
      ),
    );
  }

  // ── Thinking / streaming bubble ───────────────────────────────────────────
  Widget _buildThinkingBubble(Color primaryColor, String streamBuffer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _companionEmoji(
                  context.read<CompanionSessionManager>()
                      .session?.companionConfig.type ??
                      CompanionType.sage,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.cream.withValues(alpha: 0.07),
                ),
              ),
              child: streamBuffer.isNotEmpty
                  ? Text(
                streamBuffer,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.cream.withValues(alpha: 0.9),
                  height: 1.6,
                  fontWeight: FontWeight.w300,
                ),
              )
                  : _ThinkingDots(color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BookSession session, Color primaryColor) {
    final companion = session.companionConfig.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _companionEmoji(companion),
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _companionGreeting(companion, session.bookTitle),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                color: AppColors.cream,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select any passage and tap a quick action, or just ask me anything about this book.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(
      CompanionSessionManager manager, Color primaryColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          top: BorderSide(
            color: AppColors.cream.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Ask about this book...',
                hintStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.cream.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.cream.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.cream.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: primaryColor.withValues(alpha: 0.6),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: manager.isThinking ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: manager.isThinking
                    ? AppColors.muted.withValues(alpha: 0.2)
                    : primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: manager.isThinking
                  ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Persona helpers ───────────────────────────────────────────────────────

  String _companionEmoji(CompanionType type) {
    switch (type) {
      case CompanionType.sage:  return '🦉';
      case CompanionType.echo:  return '🌙';
      case CompanionType.spark: return '⚡';
    }
  }

  String _companionName(CompanionType type) {
    switch (type) {
      case CompanionType.sage:  return 'Sage';
      case CompanionType.echo:  return 'Echo';
      case CompanionType.spark: return 'Spark';
    }
  }

  String _companionGreeting(CompanionType type, String title) {
    switch (type) {
      case CompanionType.sage:
        return 'Ready to explore "$title" together.';
      case CompanionType.echo:
        return 'I\'m here with you through "$title".';
      case CompanionType.spark:
        return 'Let\'s get into "$title". What do you need?';
    }
  }
}

// ── Animated thinking dots ────────────────────────────────────────────────────
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final value = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = value < 0.5
                ? value * 2
                : (1.0 - value) * 2;
            return Container(
              width: 6, height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.3 + (opacity * 0.7)),
              ),
            );
          }),
        );
      },
    );
  }
}