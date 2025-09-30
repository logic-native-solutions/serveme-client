/// ---------------------------------------------------------------------------
/// Message & Conversation UI
/// ---------------------------------------------------------------------------
/// High‑level overview
///  • MessageScreen: list of conversations (search + filter + list)
///  • ConversationScreen: chat view (text, image, voice notes)
///  • SendMediaScreen: media picker + preview before sending
///  • Reusable widgets: message tiles, chips, avatars, audio bubbles
///
/// Design notes
///  • Pure Flutter/Material 3, follows app ColorScheme & typography
///  • Keyboard-safe composer; automatically scrolls to latest on focus
///  • Grouped / documented sections for maintainability
///
/// Dependencies
///  • record: microphone capture for voice notes
///  • audio players: in-bubble playback of audio
///  • image_picker: gallery/camera selection for images
/// ---------------------------------------------------------------------------
library;

// ========== Imports =========================================================
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../home/current_user.dart';

// ========== Enums & Models ==================================================

/// Filters for the conversation list.
enum MessageFilter { all, unread, read, today }

/// Chat message model supporting text, image and audio payloads.
class ChatMessage {
  ChatMessage.text({required this.isMe, required this.text, required this.time})
      : imageBytes = null,
        audioBytes = null,
        audioMillis = null;

  ChatMessage.image({required this.isMe, required this.imageBytes, required this.time})
      : text = null,
        audioBytes = null,
        audioMillis = null;

  ChatMessage.audio({required this.isMe, required this.audioBytes, required this.audioMillis, required this.time})
      : text = null,
        imageBytes = null;

  final bool isMe;
  final String? text;
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  final int? audioMillis; // duration in ms (optional)
  final String time;      // e.g., '10:31'
}

/// Media selected from the gallery/camera; returned from [SendMediaScreen].
class SelectedMedia {
  const SelectedMedia(this.bytes);
  final Uint8List bytes;
}

// ========== Utilities =======================================================

/// Returns initials for a name (e.g., "John Smith" -> "JS").
String _initialsFrom(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return (parts.first.characters.first.toString() + parts.last.characters.first.toString()).toUpperCase();
}

/// Formats [d] into a compact banner label (Today / Yesterday / dd Mon yyyy).
String _formatDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final today = DateTime.now();
  final isSameDay = d.year == today.year && d.month == today.month && d.day == today.day;
  if (isSameDay) return 'Today • ${d.day} ${months[d.month-1]} ${d.year}';
  final yesterday = today.subtract(const Duration(days: 1));
  final isYesterday = d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
  if (isYesterday) return 'Yesterday • ${d.day} ${months[d.month-1]} ${d.year}';
  return '${d.day} ${months[d.month-1]} ${d.year}';
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ========== Screens =========================================================
// -- 1) Conversation list (MessageScreen) -----------------------------------

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) => const SafeArea(child: _MessageScreen());
}

class _MessageScreen extends StatefulWidget {
  const _MessageScreen();
  @override
  State<_MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<_MessageScreen> {
  MessageFilter _filter = MessageFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Demo data (replace with your fetched conversations)
    final items = [
      (name: 'Sophia Carter', preview: "Hi, I'm available tomorrow at 2 PM.", time: '10:30 AM', unread: 0),
      (name: 'Ethan Bennett', preview: "I've sent you the invoice.", time: 'Yesterday', unread: 1),
      (name: 'Olivia Hayes', preview: 'Can we reschedule for next week?', time: '2 days ago', unread: 0),
      (name: 'Noah Thompson', preview: 'Thanks for the great service!', time: '3 days ago', unread: 0),
      (name: 'Ava Mitchell', preview: "I'm running a bit late.", time: '4 days ago', unread: 0),
    ];

    // Basic filtering demo using your MessageFilter enum
    List<( {String name, String preview, String time, int unread} )> filtered;
    switch (_filter) {
      case MessageFilter.unread:
        filtered = items.where((e) => e.unread > 0).toList();
        break;
      case MessageFilter.read:
        filtered = items.where((e) => e.unread == 0).toList();
        break;
      case MessageFilter.today:
        // Treat entries with a specific time (e.g., '10:30 AM') as today for demo
        filtered = items.where((e) => e.time.contains('AM') || e.time.contains('PM')).toList();
        break;
      case MessageFilter.all:
      filtered = items;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding (
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
            child: Text(
              'Messages',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Filter row (uses your existing _FilterChip and MessageFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == MessageFilter.all,
                    onSelected: () => setState(() => _filter = MessageFilter.all),
                  ),
                  _FilterChip(
                    label: 'Unread',
                    selected: _filter == MessageFilter.unread,
                    onSelected: () => setState(() => _filter = MessageFilter.unread),
                  ),
                  _FilterChip(
                    label: 'Read',
                    selected: _filter == MessageFilter.read,
                    onSelected: () => setState(() => _filter = MessageFilter.read),
                  ),
                  _FilterChip(
                    label: 'Today',
                    selected: _filter == MessageFilter.today,
                    onSelected: () => setState(() => _filter = MessageFilter.today),
                  ),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 500)),
              child: ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final it = filtered[i];
                  return _InboxTile(
                    name: it.name,
                    preview: it.preview,
                    timeLabel: it.time,
                    unreadCount: it.unread,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(participantName: it.name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- 2) ConversationScreen (chat view) --------------------------------------

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.participantName});
  final String participantName;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> with WidgetsBindingObserver {
  // --- Text composer state --------------------------------------------------
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  bool _hasText = false;

  // --- Scroll controller to keep latest message visible --------------------
  final ScrollController _scrollCtrl = ScrollController();

  // --- In‑memory demo messages ---------------------------------------------
  final List<ChatMessage> _messages = [
    ChatMessage.text(isMe: false, text: "Hi there! I’m excited to help you with your project. Can you tell me more about what you need?", time: '10:30'),
    ChatMessage.text(isMe: true, text: "Hi Sophia, thanks for reaching out! I need help with my garden. It's overgrown and needs some serious care.", time: '10:31'),
    ChatMessage.text(isMe: false, text: "Got it! Do you have any specific ideas or preferences for the garden?", time: '10:33'),
  ];

  // --- Voice note (record) state -------------------------------------------
  final AudioRecorder _rec = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recStart;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _isPaused = false;

  // --- Helpers --------------------------------------------------------------
  void _scrollToBottom({bool instant = false}) {
    if (!_scrollCtrl.hasClients) return;
    final target = _scrollCtrl.position.maxScrollExtent;
    if (instant) {
      _scrollCtrl.jumpTo(target);
    } else {
      _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
        }
        return;
      }
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: '', // use temporary file managed by plugin
      );
      setState(() {
        _isRecording = true;
        _recStart = DateTime.now();
        _elapsed = Duration.zero;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording || _recStart == null || _isPaused) return;
        setState(() => _elapsed = DateTime.now().difference(_recStart!));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start recording')));
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      if (!_isRecording || _isPaused) return;
      await _rec.pause();
      final paused = await _rec.isPaused();
      if (mounted) setState(() => _isPaused = paused);
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      if (!_isRecording || !_isPaused) return;
      await _rec.resume();
      final paused = await _rec.isPaused();
      if (mounted) setState(() => _isPaused = paused);
    } catch (_) {}
  }

  Future<Uint8List?> _stopRecording() async {
    try {
      final path = await _rec.stop();
      _ticker?.cancel();
      if (path == null) {
        if (mounted) setState(() => _isRecording = false);
        return null;
      }
      final bytes = await File(path).readAsBytes();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
      }
      return bytes;
    } catch (_) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save recording')));
      }
      return null;
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final bytes = await _stopRecording();
    if (bytes == null || !mounted) return;
    await _showAudioPreview(bytes, _elapsed);
  }

  Future<void> _showAudioPreview(Uint8List bytes, Duration duration) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: _AudioPreviewSheet(
            bytes: bytes,
            duration: duration,
            onSend: () {
              Navigator.of(ctx).pop();
              setState(() {
                _messages.add(
                  ChatMessage.audio(
                    isMe: true,
                    audioBytes: bytes,
                    audioMillis: duration.inMilliseconds,
                    time: TimeOfDay.now().format(context),
                  ),
                );
              });
              Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _composerController.addListener(() {
      final has = _composerController.text.trim().isNotEmpty;
      if (has != _hasText && mounted) setState(() => _hasText = has);
    });
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(instant: true));
    _composerFocus.addListener(() {
      if (_composerFocus.hasFocus) {
        // Delay slightly to allow keyboard inset to apply, then scroll.
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // When the keyboard appears or layout changes, nudge to bottom.
    Future.microtask(_scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        title: Text(widget.participantName),
        actions: [
          IconButton(tooltip: 'Call', icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: Text(_formatDate(DateTime.now())),
              ),
            ),
            ...List.generate(_messages.length, (i) {
              final m = _messages[i];
              final name = m.isMe ? 'You' : widget.participantName; // placeholder names
              final initials = m.isMe ? 'ME' : _initialsFrom(widget.participantName);
              return Padding(
                padding: EdgeInsets.only(bottom: i == _messages.length - 1 ? 0 : 12),
                child: _ChatMessage(
                  name: name,
                  text: m.text,
                  imageBytes: m.imageBytes,
                  audioBytes: m.audioBytes,
                  audioMillis: m.audioMillis,
                  time: m.time,
                  isMe: m.isMe,
                  initials: initials,
                ),
              );
            }),
          ],
        ),
      ),

      // --- Composer ---------------------------------------------------------
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              boxShadow: [
                if (_composerFocus.hasFocus || _hasText)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Material(
              elevation: _composerFocus.hasFocus ? 2 : 0,
              borderRadius: BorderRadius.circular(28),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isRecording) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.fiber_manual_record, size: 14, color: theme.colorScheme.error),
                            const SizedBox(width: 6),
                            Text(_isPaused ? 'Paused  ${_fmtDuration(_elapsed)}' : 'Recording…  ${_fmtDuration(_elapsed)}'),
                            const Spacer(),
                            IconButton(
                              tooltip: _isPaused ? 'Resume' : 'Pause',
                              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                              onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                            ),
                            IconButton(
                              tooltip: 'Stop',
                              icon: const Icon(Icons.stop),
                              onPressed: _stopRecordingAndSend,
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        // Current user avatar (placeholder initials)
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            'EC', // TODO: replace with current user initials
                            style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Text input
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _composerController,
                              focusNode: _composerFocus,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                              cursorColor: theme.colorScheme.primary,
                              decoration: InputDecoration(
                                hintText: 'Type a message',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Media picker
                        IconButton(
                          tooltip: 'Image',
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SendMediaScreen()),
                            );
                            if (result is SelectedMedia && result.bytes.isNotEmpty) {
                              setState(() {
                                _messages.add(ChatMessage.image(
                                  isMe: true,
                                  imageBytes: result.bytes,
                                  time: TimeOfDay.now().format(context),
                                ));
                              });
                              Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
                            }
                          },
                        ),

                        // Mic (when no text) OR Send button
                        if (!_hasText) ...[
                          GestureDetector(
                            onLongPressStart: (_) => _startRecording(),
                            onLongPressEnd: (_) => _stopRecordingAndSend(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isRecording ? theme.colorScheme.error : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: _isRecording ? 'Recording…' : 'Voice note',
                                icon: Icon(
                                  _isRecording ? Icons.mic : Icons.mic_none_outlined,
                                  color: _isRecording ? theme.colorScheme.onError : null,
                                ),
                                onPressed: () async {
                                  if (_isRecording) {
                                    await _stopRecordingAndSend();
                                  } else {
                                    await _startRecording();
                                  }
                                },
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                            child: IconButton(
                              tooltip: 'Send',
                              icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
                              onPressed: () {
                                final text = _composerController.text.trim();
                                if (text.isEmpty) return;
                                setState(() {
                                  _messages.add(ChatMessage.text(isMe: true, text: text, time: TimeOfDay.now().format(context)));
                                });
                                _composerController.clear();
                                FocusScope.of(context).unfocus();
                                Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -- 3) SendMediaScreen (gallery/camera picker) -----------------------------

class SendMediaScreen extends StatefulWidget {
  const SendMediaScreen({super.key});
  @override
  State<SendMediaScreen> createState() => _SendMediaScreenState();
}

class _SendMediaScreenState extends State<SendMediaScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;

  Future<void> _pickFromGallery() async {
    final XFile? x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
    if (x == null) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = b);
  }

  Future<void> _pickFromCamera() async {
    final XFile? x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048);
    if (x == null) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Send'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text('Choose from', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _PickerTile(icon: Icons.image_outlined, label: 'Gallery', onTap: _pickFromGallery),
          const SizedBox(height: 12),
          _PickerTile(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: _pickFromCamera),
          const SizedBox(height: 24),
          Text('Selected', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: (_bytes != null)
                  ? Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                ),
              )
                  : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text('No media selected', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: (_bytes != null) ? () => Navigator.of(context).pop(SelectedMedia(_bytes!)) : null,
              child: const Text('Send'),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== Reusable Widgets ===============================================

/// Filter chip matching Material 3 shape & colors.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? theme.colorScheme.onPrimaryContainer : null,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
      shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : theme.dividerColor)),
    );
  }
}

/// Conversation list tile with gradient avatar and unread badge.
class MessageListTile extends StatelessWidget {
  const MessageListTile({super.key, required this.name, required this.preview, required this.timeLabel, required this.unreadCount, required this.onTap});
  final String name;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const _GradientAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(preview, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(999)),
                    child: Text(unreadCount.toString(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular gradient avatar used in lists.
class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar();

  @override
  Widget build(BuildContext context) {
    // Example initials; for a real user you might pass a name and call _initialsFrom.
    const initials = 'JD';
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4F9A94), Color(0xFF2E7D32)]),
        ),
        alignment: Alignment.center,
        child: const Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Chat bubble with avatar + name + content (text / image / audio).
class _ChatMessage extends StatelessWidget {
  const _ChatMessage({required this.name, this.text, this.imageBytes, this.audioBytes, this.audioMillis, required this.time, required this.isMe, required this.initials});

  final String name;
  final String? text;
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  final int? audioMillis;
  final String time;
  final bool isMe;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    // Decide content widget: image > audio > text
    Widget messageContent;
    if (imageBytes != null) {
      if (isMe) {
        // Thumbnail with full‑screen preview on tap
        messageContent = GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(0),
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              height: 120,
              child: Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        );
      } else {
        messageContent = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(
              imageBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      }
    } else if (audioBytes != null && audioBytes!.isNotEmpty) {
      messageContent = _AudioBubble(bytes: audioBytes!, duration: Duration(milliseconds: audioMillis ?? 0), isMe: isMe);
    } else {
      messageContent = Text(text ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: textColor));
    }

    final bubble = Flexible(
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  messageContent,
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.9) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        isMe
            ? (CurrentUserStore.I.user?.firstName != null
                ? _initialsFrom('${CurrentUserStore.I.user?.firstName} ${CurrentUserStore.I.user?.lastName}')
                : 'ME')
            : initials,
        style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe) ...[avatar, const SizedBox(width: 10), bubble] else ...[bubble, const SizedBox(width: 10), avatar],
      ],
    );
  }
}

/// Mini audio player used inside chat bubbles.
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.bytes, required this.duration, required this.isMe});
  final Uint8List bytes;
  final Duration duration;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final AudioPlayer _player;
  Duration _pos = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPositionChanged.listen((p) => setState(() => _pos = p));
    _player.onPlayerStateChanged.listen((s) => setState(() => _playing = s == PlayerState.playing));
    _player.onPlayerComplete.listen((_) => setState(() => _pos = Duration.zero));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    await _player.stop();
    await _player.play(BytesSource(widget.bytes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.duration.inMilliseconds == 0 ? null : widget.duration;
    final progress = total == null || total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.12) : theme.colorScheme.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 22, color: widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == null ? null : progress,
                  minHeight: 4,
                  backgroundColor: widget.isMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.18) : theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(_fmtDuration(_pos), style: theme.textTheme.labelSmall?.copyWith(color: widget.isMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.9) : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for reviewing a recording before sending.
class _AudioPreviewSheet extends StatefulWidget {
  const _AudioPreviewSheet({required this.bytes, required this.duration, required this.onSend});
  final Uint8List bytes;
  final Duration duration;
  final VoidCallback onSend;

  @override
  State<_AudioPreviewSheet> createState() => _AudioPreviewSheetState();
}

class _AudioPreviewSheetState extends State<_AudioPreviewSheet> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _pos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPositionChanged.listen((p) => setState(() => _pos = p));
    _player.onPlayerStateChanged.listen((s) => setState(() => _playing = s == PlayerState.playing));
    _player.onPlayerComplete.listen((_) => setState(() => _pos = Duration.zero));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    await _player.stop();
    await _player.play(BytesSource(widget.bytes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.duration.inMilliseconds == 0 ? null : widget.duration;
    final progress = total == null || total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Voice note', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == null ? null : progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(_fmtDuration(_pos), style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.delete_outline), label: const Text('Discard')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(onPressed: widget.onSend, icon: const Icon(Icons.send), label: const Text('Send')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Onboarding/utility list tile for choosing gallery/camera.
class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
///
/// Inbox row styled like the provided mock, following Material 3 colors.
class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.name,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
    required this.onTap,
  });
  final String name;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar (gradient fallback using existing widget)
            const _GradientAvatar(),
            const SizedBox(width: 12),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.2),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Time + optional unread dot (kept subtle)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (unreadCount > 0)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}