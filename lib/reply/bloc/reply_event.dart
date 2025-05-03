part of 'reply_bloc.dart';

@immutable
sealed class ReplyEvent {}

final class ReplyNavOptionSelect extends ReplyEvent {
  final NavBarOption page;
  ReplyNavOptionSelect(this.page);
}

//Cancel Flow Event
final class ReplyCancelTaskGen extends ReplyEvent {}


//Cancel Flow Event
final class ReplySetInitialConversation extends ReplyEvent {  
  final ConversationData? conversation;

  ReplySetInitialConversation(this.conversation);

}

//Show Me Flow Events
final class ReplyFollowUpSearchVideos extends ReplyEvent {
  final String query;
  final List<ExtractedVideoInfo> savedVideos;
  final ScrollController scrollController;
  final String conversationId;

  ReplyFollowUpSearchVideos(this.query, this.savedVideos, this.conversationId, this.scrollController);
}

