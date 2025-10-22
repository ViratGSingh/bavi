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
final class ReplySetInitialAnswer extends ReplyEvent {  
  final String query;
  final String? searchId;
  final List<ExtractedVideoInfo> similarVideos;

  ReplySetInitialAnswer(this.query, this.searchId, this.similarVideos);

}

final class ReplyUpdateQuery extends ReplyEvent {  
  final String query;
  final List<ExtractedVideoInfo> similarVideos;

  ReplyUpdateQuery(this.query, this.similarVideos);

}

final class ReplyUpdateThumbnails extends ReplyEvent {  
  final List<ExtractedVideoInfo> similarVideos;

  ReplyUpdateThumbnails(this.similarVideos);

}

final class ReplySearchResultShare extends ReplyEvent {}

final class ReplyRefreshAnswer extends ReplyEvent {  
  final String query;
  final int answerNumber;
  final List<ExtractedVideoInfo> similarVideos;

  ReplyRefreshAnswer( this.query, this.answerNumber, this.similarVideos);

}

final class ReplyNextAnswer extends ReplyEvent {  
  final String query;
  final int answerNumber;
  final List<ExtractedVideoInfo> similarVideos;

  ReplyNextAnswer(this.query, this.answerNumber,this.similarVideos);
}

final class ReplyPreviousAnswer extends ReplyEvent {  
  
  ReplyPreviousAnswer();
}

//Show Me Flow Events
final class ReplyFollowUpAnswer extends ReplyEvent {
  final String query;
  final List<ExtractedVideoInfo> savedVideos;
  final ScrollController scrollController;
  final String conversationId;

  ReplyFollowUpAnswer(this.query, this.savedVideos, this.conversationId, this.scrollController);
}

