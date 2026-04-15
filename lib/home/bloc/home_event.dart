part of 'home_bloc.dart';

// // ignore: depend_on_referenced_packages
// import 'package:image_picker/image_picker.dart';

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
final class HomeExtractUrlData extends HomeEvent {
  final String inputUrl;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;

  HomeExtractUrlData(this.inputUrl, this.extractedUrlDescription,
      this.extractedUrlTitle, this.extractedUrl, this.extractedImageUrl);
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

//Search Type Portal
final class HomePortalSearch extends HomeEvent {
  final String query;

  HomePortalSearch(this.query);
}

//Model Select
final class HomeModelSelect extends HomeEvent {
  final HomeModel model;
  HomeModelSelect(this.model);
}

//Search Type Switch
final class HomeGenScreenshot extends HomeEvent {
  final GlobalKey globalKey;
  HomeGenScreenshot(this.globalKey);
}

// Web search results received from GoogleSearchWebView
final class HomeWebSearchResultsReceived extends HomeEvent {
  final List<ExtractedResultInfo> results;
  final List<VisualBrowseResultData> browseImages;
  HomeWebSearchResultsReceived(this.results, {this.browseImages = const []});
}

//Watch Google Search
final class HomeGetAnswer extends HomeEvent {
  final String query;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;
  final String imageDescription;
  final ValueNotifier<String> imageDescriptionNotifier;
  final bool ignoreLocation;

  HomeGetAnswer(
      this.query,
      this.streamedText,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl,
      this.imageDescription,
      this.imageDescriptionNotifier,
      {this.ignoreLocation = false});
}

//Watch Google Map Search
final class HomeGetMapAnswer extends HomeEvent {
  final String query;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;
  final String imageDescription;
  final ValueNotifier<String> imageDescriptionNotifier;

  HomeGetMapAnswer(
      this.query,
      this.streamedText,
      this.imageDescription,
      this.imageDescriptionNotifier,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl);
}

//Watch Google Search
final class HomeUpdateAnswer extends HomeEvent {
  final String query;
  final int index;
  final String imageDescription;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;
  final ValueNotifier<String> imageDescriptionNotifier;

  HomeUpdateAnswer(
      this.query,
      this.index,
      this.streamedText,
      this.imageDescription,
      this.imageDescriptionNotifier,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl);
}

//Watch Google Search
final class HomeUpdateMapAnswer extends HomeEvent {
  final String query;
  final int index;
  final String imageDescription;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> imageDescriptionNotifier;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;

  HomeUpdateMapAnswer(
      this.query,
      this.index,
      this.streamedText,
      this.imageDescription,
      this.imageDescriptionNotifier,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl);
}

//Watch Google Search
final class HomeGetSearch extends HomeEvent {
  final String query;
  final String type;

  HomeGetSearch(this.query, this.type);
}

//Watch Google ActionType
final class HomeSwitchActionType extends HomeEvent {
  final String query;

  HomeSwitchActionType(this.query);
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

//Select SearchType
final class HomeSearchTypeSelected extends HomeEvent {
  final HomeSearchType searchType;

  HomeSearchTypeSelected(this.searchType);
}

//Select Edit Option
final class SelectEditInputOption extends HomeEvent {
  final String query;
  final bool isEditMode;
  final int index;
  final bool isSearchMode;
  final String uploadedImageUrl;
  SelectEditInputOption(this.query, this.isEditMode, this.index,
      this.isSearchMode, this.uploadedImageUrl);
}

//Retrieve Search Data
final class HomeRetrieveSearchData extends HomeEvent {
  final ThreadSessionData sessionData;

  HomeRetrieveSearchData(this.sessionData);
}

final class HomeInitialUserData extends HomeEvent {}

final class HomeAttemptGoogleSignIn extends HomeEvent {}

final class HomeAttemptGoogleSignOut extends HomeEvent {}

final class HomeImageSelected extends HomeEvent {
  final XFile image;
  final ValueNotifier<String> imageDescription;
  HomeImageSelected(this.image, this.imageDescription);
}

final class HomeImageUnselected extends HomeEvent {
  final ValueNotifier<String> imageDescription;
  HomeImageUnselected(this.imageDescription);
}

final class HomeCancelOCRExtraction extends HomeEvent {
  final ValueNotifier<String> imageDescription;
  HomeCancelOCRExtraction(this.imageDescription);
}

final class HomeToggleMapStatus extends HomeEvent {}

final class HomeToggleYoutubeStatus extends HomeEvent {}

final class HomeToggleSpicyStatus extends HomeEvent {}

final class HomeToggleInstagramStatus extends HomeEvent {}

final class HomeToggleGeneralStatus extends HomeEvent {}

final class HomeShowLocationRationale extends HomeEvent {}

final class HomeRetryPendingSearch extends HomeEvent {
  final bool ignoreLocation;
  HomeRetryPendingSearch({this.ignoreLocation = false});
}

final class HomeCheckLocationAndAnswer extends HomeEvent {
  final String query;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;
  final String imageDescription;
  final ValueNotifier<String> imageDescriptionNotifier;
  HomeCheckLocationAndAnswer(
      this.query,
      this.streamedText,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl,
      this.imageDescription,
      this.imageDescriptionNotifier);
}

final class HomeToggleChatMode extends HomeEvent {}

final class HomeToggleDeepDrissy extends HomeEvent {}

final class HomeDeepDrissyGetAnswer extends HomeEvent {
  final String query;
  final ValueNotifier<String> streamedText;
  final ValueNotifier<String> extractedUrlDescription;
  final ValueNotifier<String> extractedUrlTitle;
  final ValueNotifier<String> extractedUrl;
  final ValueNotifier<String> extractedImageUrl;
  final String imageDescription;
  final ValueNotifier<String> imageDescriptionNotifier;

  HomeDeepDrissyGetAnswer(
      this.query,
      this.streamedText,
      this.extractedUrlDescription,
      this.extractedUrlTitle,
      this.extractedUrl,
      this.extractedImageUrl,
      this.imageDescription,
      this.imageDescriptionNotifier);
}

final class HomeDeepDrissyWebSearchResultsReceived extends HomeEvent {
  final List<ExtractedResultInfo> results;
  HomeDeepDrissyWebSearchResultsReceived(this.results);
}

/// Local AI model download/load events
final class HomeLocalAIDownloadAndLoad extends HomeEvent {}

/// Load model into memory if already downloaded (no download)
final class HomeLocalAILoadIfDownloaded extends HomeEvent {}

final class HomeLocalAIDownloadProgress extends HomeEvent {
  final double progress;
  HomeLocalAIDownloadProgress(this.progress);
}

/// Gemma 4 download/load events
final class HomeGemma4DownloadAndLoad extends HomeEvent {}
final class HomeGemma4LoadIfDownloaded extends HomeEvent {}

/// Liquid AI download/load events
final class HomeLiquidAIDownloadAndLoad extends HomeEvent {}
final class HomeLiquidAILoadIfDownloaded extends HomeEvent {}

/// Bonsai download/load events
final class HomeBonsaiDownloadAndLoad extends HomeEvent {}
final class HomeBonsaiLoadIfDownloaded extends HomeEvent {}

/// Check on startup if secondary model files exist on disk (no engine load)
final class HomeCheckSecondaryModelsDownloaded extends HomeEvent {}

final class HomeDeleteAllHistory extends HomeEvent {}

final class HomeObsidianNoteSelected extends HomeEvent {
  final String noteName;
  final String noteContent;
  HomeObsidianNoteSelected(this.noteName, this.noteContent);
}

final class HomeObsidianNoteCleared extends HomeEvent {}

final class HomeVisualBrowseCompleted extends HomeEvent {
  final String query;
  final List<VisualBrowseResultData> images;
  HomeVisualBrowseCompleted(this.query, this.images);
}

final class HomeToggleVisualBrowse extends HomeEvent {}

final class HomeVisualBrowseStart extends HomeEvent {
  final String query;
  final ValueNotifier<List<VisualBrowseResultData>> visualBrowseNotifier;
  final ValueNotifier<String> streamedText;
  HomeVisualBrowseStart(this.query, this.visualBrowseNotifier, this.streamedText);
}

final class HomeVisualBrowseImagesExtracted extends HomeEvent {
  final List<VisualBrowseImageData> images;
  HomeVisualBrowseImagesExtracted(this.images);
}

// ── Moodboard ──────────────────────────────────────────────────────────────

final class HomeToggleMoodboard extends HomeEvent {}

final class HomeMoodboardStart extends HomeEvent {
  final String query;
  final ValueNotifier<List<MoodboardResultData>> moodboardNotifier;
  final ValueNotifier<String> progressNotifier;
  /// All extracted image URIs (accepted + still scanning) for the scanning UI
  final ValueNotifier<List<String>> scanImagesNotifier;
  HomeMoodboardStart(
      this.query, this.moodboardNotifier, this.progressNotifier, this.scanImagesNotifier);
}

final class HomeMoodboardImagesExtracted extends HomeEvent {
  final List<VisualBrowseImageData> images;
  HomeMoodboardImagesExtracted(this.images);
}

final class HomeMoodboardCompleted extends HomeEvent {
  final String query;
  final List<MoodboardResultData> images;
  HomeMoodboardCompleted(this.query, this.images);
}

/// Model deletion events
final class HomeDeleteLocalAIModel extends HomeEvent {}
final class HomeDeleteGemma4Model extends HomeEvent {}
final class HomeDeleteLiquidAIModel extends HomeEvent {}
final class HomeDeleteBonsaiModel extends HomeEvent {}

/// Load the last model the user selected (persisted across launches)
final class HomeLoadSavedModel extends HomeEvent {}
