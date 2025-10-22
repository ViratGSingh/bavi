part of 'answer_bloc.dart';

@immutable
sealed class AnswerEvent {}

final class AnswerUpdateThumbnails extends AnswerEvent{  
  final List<String> sourceUrls;
  AnswerUpdateThumbnails(this.sourceUrls);
}


final class AnswerSearchResultShare extends AnswerEvent {
  final String searchId;
  AnswerSearchResultShare(this.searchId);
}
