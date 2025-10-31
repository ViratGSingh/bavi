import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp





class ThreadResultData extends Equatable {
  final List<WebResultData> web;
  final List<ShortVideoResultData> shortVideos;
  final List<VideoResultData> videos;
  final List<NewsResultData> news;
  final List<ImageResultData> images;
  final Timestamp createdAt;
  Timestamp updatedAt;
  final String userQuery;
  final String searchQuery;
  final String answer;
  final List<InfluenceData> influence;
  final bool isSearchMode;

   ThreadResultData({
    required this.web,
    required this.shortVideos,
    required this.videos,
    required this.news,
    required this.images,
    required this.createdAt,
    required this.updatedAt,
    required this.userQuery,
    required this.searchQuery,
    required this.answer,
    required this.influence,
    required this.isSearchMode,
  });

  factory ThreadResultData.fromJson(Map<String, dynamic> json) {
    return ThreadResultData(
      web: (json['web'] as List<dynamic>?)
              ?.map((e) => WebResultData.fromJson(e))
              .toList() ??
          [],
      shortVideos: (json['short_videos'] as List<dynamic>?)
              ?.map((e) => ShortVideoResultData.fromJson(e))
              .toList() ??
          [],
      videos: (json['videos'] as List<dynamic>?)
              ?.map((e) => VideoResultData.fromJson(e))
              .toList() ??
          [],
      news: (json['news'] as List<dynamic>?)
              ?.map((e) => NewsResultData.fromJson(e))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ImageResultData.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt']
          : (json['createdAt'] != null
              ? Timestamp.fromDate(DateTime.parse(json['createdAt']))
              : Timestamp.now()),
      updatedAt: json['updatedAt'] is Timestamp
          ? json['updatedAt']
          : (json['updatedAt'] != null
              ? Timestamp.fromDate(DateTime.parse(json['updatedAt']))
              : Timestamp.now()),
      userQuery: json['userQuery'] ?? '',
      searchQuery: json['searchQuery'] ?? '',
      answer: json['answer'] ?? '',
      influence: (json['influence'] as List<dynamic>?)
              ?.map((e) => InfluenceData.fromJson(e))
              .toList() ??
          [],
      isSearchMode: json['isSearchMode'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'web': web.map((e) => e.toJson()).toList(),
        'short_videos': shortVideos.map((e) => e.toJson()).toList(),
        'videos': videos.map((e) => e.toJson()).toList(),
        'news': news.map((e) => e.toJson()).toList(),
        'images': images.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toDate().toIso8601String(),
        'updatedAt': updatedAt.toDate().toIso8601String(),
        'userQuery': userQuery,
        'searchQuery': searchQuery,
        'answer': answer,
        'influence': influence.map((e) => e.toJson()).toList(),
        'isSearchMode': isSearchMode,
      };

  @override
  List<Object> get props => [web, shortVideos, videos, news, images, createdAt, updatedAt, userQuery, searchQuery, answer, influence, isSearchMode];
}

class WebResultData extends Equatable {
  final int position;
  final String title;
  final String link;
  final String displayedLink;
  final String snippet;

  const WebResultData({
    required this.position,
    required this.title,
    required this.link,
    required this.displayedLink,
    required this.snippet,
  });

  factory WebResultData.fromJson(Map<String, dynamic> json) => WebResultData(
        position: json['position'] ?? 0,
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        displayedLink: json['displayed_link'] ?? '',
        snippet: json['snippet'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        'link': link,
        'displayed_link': displayedLink,
        'snippet': snippet,
      };

  @override
  List<Object> get props => [position, title, link, displayedLink, snippet];
}

class ShortVideoResultData extends Equatable {
  final String title;
  final String link;
  final String thumbnail;
  final String clip;
  final String source;
  final String sourceIcon;
  final String channel;
  final String duration;

  const ShortVideoResultData({
    required this.title,
    required this.link,
    required this.thumbnail,
    required this.clip,
    required this.source,
    required this.sourceIcon,
    required this.channel,
    required this.duration,
  });

  factory ShortVideoResultData.fromJson(Map<String, dynamic> json) =>
      ShortVideoResultData(
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        clip: json['clip'] ?? '',
        source: json['source'] ?? '',
        sourceIcon: json['source_icon'] ?? '',
        channel: json['channel'] ?? '',
        duration: json['duration'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'thumbnail': thumbnail,
        'clip': clip,
        'source': source,
        'source_icon': sourceIcon,
        'channel': channel,
        'duration': duration,
      };

  @override
  List<Object> get props =>
      [title, link, thumbnail, clip, source, sourceIcon, channel, duration];
}

class VideoResultData extends Equatable {
  final String title;
  final String link;
  final String displayedLink;
  final String thumbnail;
  final String snippet;
  final String duration;
  final String date;

  const VideoResultData({
    required this.title,
    required this.link,
    required this.displayedLink,
    required this.thumbnail,
    required this.snippet,
    required this.duration,
    required this.date,
  });

  factory VideoResultData.fromJson(Map<String, dynamic> json) => VideoResultData(
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        displayedLink: json['displayed_link'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        snippet: json['snippet'] ?? '',
        duration: json['duration'] ?? '',
        date: json['date'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'displayed_link': displayedLink,
        'thumbnail': thumbnail,
        'snippet': snippet,
        'duration': duration,
        'date': date,
      };

  @override
  List<Object> get props =>
      [title, link, displayedLink, thumbnail, snippet, duration, date];
}

class NewsResultData extends Equatable {
  final String title;
  final String link;
  final String source;
  final String thumbnail;
  final String snippet;
  final String date;

  const NewsResultData({
    required this.title,
    required this.link,
    required this.source,
    required this.thumbnail,
    required this.snippet,
    required this.date,
  });

  factory NewsResultData.fromJson(Map<String, dynamic> json) => NewsResultData(
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        source: json['source'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        snippet: json['snippet'] ?? '',
        date: json['date'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'source': source,
        'thumbnail': thumbnail,
        'snippet': snippet,
        'date': date,
      };

  @override
  List<Object> get props => [title, link, source, thumbnail, snippet, date];
}

class ImageResultData extends Equatable {
  final int position;
  final String title;
  final String source;
  final String link;
  final String rawLink;
  final String original;
  final int originalWidth;
  final int originalHeight;
  final String thumbnail;
  final String serpapiThumbnail;
  final String relatedContentId;
  final String serpapiRelatedContentLink;

  const ImageResultData({
    required this.position,
    required this.title,
    required this.source,
    required this.link,
    required this.rawLink,
    required this.original,
    required this.originalWidth,
    required this.originalHeight,
    required this.thumbnail,
    required this.serpapiThumbnail,
    required this.relatedContentId,
    required this.serpapiRelatedContentLink,
  });

  factory ImageResultData.fromJson(Map<String, dynamic> json) => ImageResultData(
        position: json['position'] ?? 0,
        title: json['title'] ?? '',
        source: json['source'] ?? '',
        link: json['link'] ?? '',
        rawLink: json['raw_link'] ?? '',
        original: json['original'] ?? '',
        originalWidth: json['original_width'] ?? 0,
        originalHeight: json['original_height'] ?? 0,
        thumbnail: json['thumbnail'] ?? '',
        serpapiThumbnail: json['serpapi_thumbnail'] ?? '',
        relatedContentId: json['related_content_id'] ?? '',
        serpapiRelatedContentLink: json['serpapi_related_content_link'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        'source': source,
        'link': link,
        'raw_link': rawLink,
        'original': original,
        'original_width': originalWidth,
        'original_height': originalHeight,
        'thumbnail': thumbnail,
        'serpapi_thumbnail': serpapiThumbnail,
        'related_content_id': relatedContentId,
        'serpapi_related_content_link': serpapiRelatedContentLink,
      };

  @override
  List<Object> get props => [
        position,
        title,
        source,
        link,
        rawLink,
        original,
        originalWidth,
        originalHeight,
        thumbnail,
        serpapiThumbnail,
        relatedContentId,
        serpapiRelatedContentLink,
      ];
}

class InfluenceData extends Equatable {
  final String url;
  final String snippet;
  final String title;
  final double similarity;

  const InfluenceData({
    required this.url,
    required this.snippet,
    required this.title,
    required this.similarity,
  });

  factory InfluenceData.fromJson(Map<String, dynamic> json) => InfluenceData(
        url: json['url'] ?? '',
        snippet: json['snippet'] ?? '',
        title: json['title'] ?? '',
        similarity: (json['similarity'] is int)
            ? (json['similarity'] as int).toDouble()
            : (json['similarity'] ?? 0.0),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'snippet': snippet,
        'title': title,
        'similarity': similarity,
      };

  @override
  List<Object> get props => [url, snippet,title, similarity];
}

class ThreadSessionData extends Equatable {
  final String id;
  final List<ThreadResultData> results;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String email;

  const ThreadSessionData({
    required this.id,
    required this.email,
    required this.results,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThreadSessionData.fromJson(Map<String, dynamic> json) {
    return ThreadSessionData(
      id: json['id'] ?? '',
      email:json['email'] ?? '',
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => ThreadResultData.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt']
          : (json['createdAt'] != null
              ? Timestamp.fromDate(DateTime.parse(json['createdAt']))
              : Timestamp.now()),
      updatedAt: json['updatedAt'] is Timestamp
          ? json['updatedAt']
          : (json['updatedAt'] != null
              ? Timestamp.fromDate(DateTime.parse(json['updatedAt']))
              : Timestamp.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'results': results.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toDate().toIso8601String(),
        'updatedAt': updatedAt.toDate().toIso8601String(),
      };

  @override
  List<Object> get props => [id, email ,results, createdAt, updatedAt];
}