part of 'home_bloc.dart';

enum NavBarOption { home, search, player, profile }

enum HomePageStatus { idle, loading, generateQuery, getSearchResults,summarize,  success, failure}

final class HomeState extends Equatable {
  HomeState({
    UserProfileInfo? userData,
    this.page = NavBarOption.home,
    this.status = HomePageStatus.idle,
    this.searchResults = const [],
    this.searchAnswer = "",
    this.account = const ExtractedAccountInfo(
      accountId: "bengaluru_food_scene", 
      username: "Let us put one full scene together", 
      fullname: "Bengaluru Food Scene", 
      profilePicUrl: "https://bavi.s3.ap-south-1.amazonaws.com/profiles/bengaluru_food_scene.png", 
      isVerified: false, 
      isPrivate: false),
    this.searchQuery = "",
    this.searchHistory = const []
  }) : userData = userData ?? UserProfileInfo(
          email: "NA",
          fullname: "NA",
          username: "NA",
          profilePicUrl: "NA",
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          searchHistory: [],
        );
  final String searchQuery;
  final UserProfileInfo userData;
  final NavBarOption page;
  final HomePageStatus status;
  final List<ConversationData> searchHistory;
  final List<ExtractedVideoInfo> searchResults;
  final String searchAnswer;
  ExtractedAccountInfo account;
  HomeState copyWith({
    String? searchQuery,
    UserProfileInfo? userData,
    NavBarOption? page,
    ExtractedAccountInfo? account,
    HomePageStatus? status,
    String? searchAnswer,
    List<ConversationData>? searchHistory,
    List<ExtractedVideoInfo>? searchResults,
  }) {
    return HomeState(
      searchHistory: searchHistory ?? this.searchHistory,
      searchAnswer: searchAnswer ?? this.searchAnswer,
      searchQuery: searchQuery ?? this.searchQuery,
      account: account ?? this.account,
      userData: userData ?? this.userData,
      page: page ?? this.page,
      status: status ?? this.status,
      searchResults: searchResults ?? this.searchResults,
    );
  }

  @override
  List<Object?> get props => [page,account, status, userData,searchHistory, searchResults, searchAnswer];
}
