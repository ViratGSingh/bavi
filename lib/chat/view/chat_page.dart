import 'dart:async';
import 'dart:io';
import 'package:bavi/chat/bloc/chat_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String? initialMessage;

  const ChatPage({super.key, this.initialMessage});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<String> _streamedText = ValueNotifier("");
  final ValueNotifier<String> _imageDescription = ValueNotifier("");

  bool _isInputValid = false;
  bool _initialMessageSent = false;
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _streamedText.dispose();
    _imageDescription.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(BuildContext context) {
    if (_messageController.text.trim().isEmpty) return;

    // Clear streamed text for fresh streaming
    _streamedText.value = '';

    context.read<ChatBloc>().add(
          ChatSendMessage(_messageController.text.trim(), _streamedText),
        );
    _messageController.clear();
    setState(() => _isInputValid = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatBloc>(
      create: (context) => ChatBloc()..add(ChatLoadHistory()),
      child: Builder(
        builder: (context) {
          // Send initial message after bloc is created
          if (!_initialMessageSent &&
              widget.initialMessage != null &&
              widget.initialMessage!.isNotEmpty) {
            _initialMessageSent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _streamedText.value = ''; // Clear for fresh streaming
              context.read<ChatBloc>().add(
                    ChatSendMessage(widget.initialMessage!, _streamedText),
                  );
            });
          }

          return BlocConsumer<ChatBloc, ChatState>(
            listener: (context, state) {
              if (state.status == ChatPageStatus.success ||
                  state.replyStatus == ChatReplyStatus.loading) {
                _scrollToBottom();
              }
            },
            builder: (context, state) {
              return Scaffold(
                backgroundColor: Colors.white,
                appBar: _buildAppBar(context, state),
                body: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    children: [
                      Expanded(
                        child: state.messages.isEmpty &&
                                state.replyStatus != ChatReplyStatus.loading
                            ? _buildEmptyState()
                            : _buildMessageList(state),
                      ),
                      _buildInputArea(context, state),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatState state) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB388FF), Color(0xFF8A2BE2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.message_text_1_bold,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offline Chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Offline Chat',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'clear') {
              context.read<ChatBloc>().add(ChatClearHistory());
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Clear Chat', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFB388FF).withOpacity(0.3),
                  const Color(0xFF8A2BE2).withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Iconsax.message_text_1_bold,
              color: Color(0xFF8A2BE2),
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat privately, completely offline.\nYour messages never leave your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: state.messages.length +
          (state.replyStatus == ChatReplyStatus.loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length &&
            state.replyStatus == ChatReplyStatus.loading) {
          // Show streaming response bubble instead of just typing indicator
          return _buildStreamingBubble();
        }

        final message = state.messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildStreamingBubble() {
    return ValueListenableBuilder<String>(
      valueListenable: _streamedText,
      builder: (context, streamedValue, child) {
        // If no content yet, show typing indicator
        if (streamedValue.isEmpty) {
          return _buildTypingIndicator();
        }

        // Show the streaming text in a bubble
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB388FF), Color(0xFF8A2BE2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Iconsax.message_text_1_bold,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    streamedValue,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB388FF), Color(0xFF8A2BE2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Iconsax.message_text_1_bold,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF8A2BE2) : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? const Color(0xFF8A2BE2) : Colors.grey)
                        .withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFDFFF00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF8A2BE2),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB388FF), Color(0xFF8A2BE2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.message_text_1_bold,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _typingAnimationController,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final animValue =
                        (_typingAnimationController.value + delay) % 1.0;
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.grey.shade400,
                          const Color(0xFF8A2BE2),
                          animValue,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview if selected
              if (state.imageStatus == ChatImageStatus.selected &&
                  state.selectedImage != null)
                _buildImagePreview(context, state),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Add image button
                    GestureDetector(
                      onTap: () => _pickImage(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(left: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),

                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(
                              () => _isInputValid = value.trim().length >= 2);
                        },
                        onSubmitted: (_) {
                          if (_isInputValid &&
                              state.replyStatus != ChatReplyStatus.loading) {
                            _sendMessage(context);
                          }
                        },
                      ),
                    ),

                    // Send button
                    state.replyStatus != ChatReplyStatus.loading
                        ? GestureDetector(
                            onTap: () {
                              if (_isInputValid) {
                                _sendMessage(context);
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin:
                                  const EdgeInsets.only(right: 4, bottom: 4),
                              decoration: BoxDecoration(
                                color: _isInputValid
                                    ? const Color(0xFF8A2BE2)
                                    : const Color(0xFFC99DF2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward,
                                color: Color(0xFFDFFF00),
                                size: 20,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              context
                                  .read<ChatBloc>()
                                  .add(ChatCancelResponse());
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              margin:
                                  const EdgeInsets.only(right: 4, bottom: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8A2BE2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.stop,
                                color: Color(0xFFDFFF00),
                                size: 20,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // Privacy indicator
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'End-to-end private • Never leaves your device',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, ChatState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(state.selectedImage!.path),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Image selected',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Ready to analyze',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              context
                  .read<ChatBloc>()
                  .add(ChatImageUnselected(_imageDescription));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && context.mounted) {
      context.read<ChatBloc>().add(ChatImageSelected(image, _imageDescription));
    }
  }
}
