part of 'home_bloc.dart';

@immutable
sealed class HomeEvent {}

final class HomeNavOptionSelect extends HomeEvent {
  final NavBarOption page;
  HomeNavOptionSelect(this.page);
}


final class HomeAccountSelect extends HomeEvent {
  final ExtractedAccountInfo accountInfo;
  HomeAccountSelect(this.accountInfo);
}

final class HomeAccountDeselect extends HomeEvent {}

final class HomeSelectSearch extends HomeEvent {}

final class HomeYoutubeTaskGenSearchQuery extends HomeEvent {
  final String task;
  HomeYoutubeTaskGenSearchQuery(this.task);
}

//Cancel Flow Event
final class HomeCancelTaskGen extends HomeEvent {}

final class HomeNavToReply extends HomeEvent {
  final ConversationData conversationData;

  HomeNavToReply(this.conversationData);
}

//Search
final class HomeSearchVideos extends HomeEvent {
  final String query;
  final int topK;
  final String userId;

  HomeSearchVideos(this.query, this.topK, this.userId);
}

final class HomeInitialUserData extends HomeEvent {}


final class HomeAttemptGoogleSignIn extends HomeEvent {
}


final class HomeAttemptGoogleSignOut extends HomeEvent {
}


