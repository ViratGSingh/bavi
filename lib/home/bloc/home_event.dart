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
  final SearchData searchData;

  HomeNavToReply(this.searchData);
}

//Search
final class HomeSearchVideos extends HomeEvent {
  final String query;
  final int topK;
  final String userId;

  HomeSearchVideos(this.query, this.topK, this.userId);
}

//Glance Search
final class AltHomeSearchVideos extends HomeEvent {
  final String query;
  final String searchId;

  AltHomeSearchVideos(this.query, this.searchId);
}

//Watch Search
final class HomeWatchSearchVideos extends HomeEvent {
  final String query;
  final String searchId;

  HomeWatchSearchVideos(this.query, this.searchId);
}

//Search Type Switch
final class HomeSwitchSearchType extends HomeEvent {
  final String searchType;

  HomeSwitchSearchType(this.searchType);
}

//Search Type Incognito Switch
final class HomeSwitchPrivacyType extends HomeEvent {
  final bool isIncognito;

  HomeSwitchPrivacyType(this.isIncognito);
}

//Search Type Switch
final class HomeGenScreenshot extends HomeEvent {
  final GlobalKey globalKey;
  HomeGenScreenshot(this.globalKey);
}

//Watch Google Search
final class HomeWatchSearchResults extends HomeEvent {
  final String query;

  HomeWatchSearchResults(this.query);
}

//Ask Followup Search
final class HomeFollowUpSearchVideos extends HomeEvent {
  final String query;

  HomeFollowUpSearchVideos(this.query);
}

final class HomeFollowUpRecallVideos extends HomeEvent {
  final String query;

  HomeFollowUpRecallVideos(this.query);
}

final class HomeRefreshReply extends HomeEvent {
  final bool isSearchMode;
  HomeRefreshReply(this.isSearchMode);
}

//Ask Recall Search
final class HomeRecallSearchVideos extends HomeEvent {
  final String query;

  HomeRecallSearchVideos(this.query);
}

//Retrieve Search Data
final class HomeRetrieveSearchData extends HomeEvent {
  final SessionData sessionData;

  HomeRetrieveSearchData(this.sessionData);
}


final class HomeInitialUserData extends HomeEvent {}


final class HomeAttemptGoogleSignIn extends HomeEvent {
}


final class HomeAttemptGoogleSignOut extends HomeEvent {
}


