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
final class HomeSwitchType extends HomeEvent {
  final bool type;

  HomeSwitchType(this.type);
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
final class HomeGetAnswer extends HomeEvent {
  final String query;
  ValueNotifier<String> streamedText;

  HomeGetAnswer(this.query, this.streamedText);
}

//Watch Google Search
final class HomeUpdateAnswer extends HomeEvent {
  final String query;
  final int index;
  ValueNotifier<String> streamedText;

  HomeUpdateAnswer(this.query, this.index, this.streamedText);
}

//Watch Google Search
final class HomeGetSearch extends HomeEvent {
  final String query;
  final String type;

  HomeGetSearch(this.query, this.type);
}

//Watch Reels Search
final class HomeGetReelsSearch extends HomeEvent {
  final int index;

  HomeGetReelsSearch(this.index);
}
//Watch Videos Search
final class HomeGetVideosSearch extends HomeEvent {
  final int index;

  HomeGetVideosSearch(this.index);
}

//Watch Images Search
final class HomeGetImagesSearch extends HomeEvent {
  final int index;

  HomeGetImagesSearch(this.index);
}

//Watch News Search
final class HomeGetNewsSearch extends HomeEvent {
  final int index;

  HomeGetNewsSearch(this.index);
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

final class HomeStartNewThread extends HomeEvent {

  HomeStartNewThread();
}

final class HomeRefreshReply extends HomeEvent {
  final int index;
  final ValueNotifier<String> streamedText;
  HomeRefreshReply(this.index, this.streamedText);
}

//Ask Recall Search
final class HomeRecallSearchVideos extends HomeEvent {
  final String query;

  HomeRecallSearchVideos(this.query);
}

//Select Edit Option
final class SelectEditInputOption extends HomeEvent {
  final String query;
  final bool isEditMode;
  final int index;
  final bool isSearchMode;
  SelectEditInputOption(this.query, this.isEditMode, this.index, this.isSearchMode);
}

//Retrieve Search Data
final class HomeRetrieveSearchData extends HomeEvent {
  final ThreadSessionData sessionData;

  HomeRetrieveSearchData(this.sessionData);
}


final class HomeInitialUserData extends HomeEvent {}


final class HomeAttemptGoogleSignIn extends HomeEvent {
}


final class HomeAttemptGoogleSignOut extends HomeEvent {
}


