part of 'chat_bloc.dart';

enum ChatPageStatus {
  idle,
  loading,
  success,
  failure,
}

enum ChatReplyStatus { loading, success, failure, idle }

enum ChatImageStatus { selected, unselected }

const _sentinel = Object();

final class ChatState extends Equatable {
  const ChatState({
    this.status = ChatPageStatus.idle,
    this.replyStatus = ChatReplyStatus.idle,
    this.imageStatus = ChatImageStatus.unselected,
    this.selectedImage,
    this.isAnalyzingImage = false,
    this.messages = const [],
    this.currentQuery = '',
  });

  final ChatPageStatus status;
  final ChatReplyStatus replyStatus;
  final ChatImageStatus imageStatus;
  final XFile? selectedImage;
  final bool isAnalyzingImage;
  final List<ChatMessage> messages;
  final String currentQuery;

  ChatState copyWith({
    ChatPageStatus? status,
    ChatReplyStatus? replyStatus,
    ChatImageStatus? imageStatus,
    Object? selectedImage = _sentinel,
    bool? isAnalyzingImage,
    List<ChatMessage>? messages,
    String? currentQuery,
  }) {
    return ChatState(
      status: status ?? this.status,
      replyStatus: replyStatus ?? this.replyStatus,
      imageStatus: imageStatus ?? this.imageStatus,
      selectedImage: selectedImage == _sentinel
          ? this.selectedImage
          : selectedImage as XFile?,
      isAnalyzingImage: isAnalyzingImage ?? this.isAnalyzingImage,
      messages: messages ?? this.messages,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }

  @override
  List<Object?> get props => [
        status,
        replyStatus,
        imageStatus,
        selectedImage,
        isAnalyzingImage,
        messages,
        currentQuery,
      ];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.content,
    required this.isUser,
    this.timestamp,
  });

  final String content;
  final bool isUser;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [content, isUser, timestamp];
}
