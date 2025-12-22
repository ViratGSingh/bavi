part of 'chat_bloc.dart';

@immutable
sealed class ChatEvent {}

/// Load chat history from local storage
final class ChatLoadHistory extends ChatEvent {}

/// Send a message in the offline chat
final class ChatSendMessage extends ChatEvent {
  final String query;
  final ValueNotifier<String> streamedText;

  ChatSendMessage(this.query, this.streamedText);
}

/// Clear the chat history
final class ChatClearHistory extends ChatEvent {}

/// Start a new chat session
final class ChatStartNewSession extends ChatEvent {}

/// Select an image for the chat
final class ChatImageSelected extends ChatEvent {
  final XFile image;
  final ValueNotifier<String> imageDescription;

  ChatImageSelected(this.image, this.imageDescription);
}

/// Unselect the current image
final class ChatImageUnselected extends ChatEvent {
  final ValueNotifier<String> imageDescription;

  ChatImageUnselected(this.imageDescription);
}

/// Cancel the current response generation
final class ChatCancelResponse extends ChatEvent {}
