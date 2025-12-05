import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Timestamp

class ThreadResultData extends Equatable {
  final List<WebResultData> web;
  final List<ShortVideoResultData> shortVideos;
  final List<VideoResultData> videos;
  final List<NewsResultData> news;
  final List<ImageResultData> images;
  final KnowledgeGraphData? knowledgeGraph;
  final AnswerBoxData? answerBox;
  final Timestamp createdAt;
  Timestamp updatedAt;
  final String userQuery;
  final String searchQuery;
  final String answer;
  final String sourceImageDescription;
  final String sourceImageLink;
  final List<InfluenceData> influence;
  final bool isSearchMode;
  final List<LocalResultData> local;
  final HomeSearchType searchType;
  final ExtractedUrlResultData? extractedUrlData;

  ThreadResultData({
    required this.searchType,
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
    required this.sourceImageDescription,
    required this.sourceImageLink,
    required this.local,
    this.knowledgeGraph,
    this.answerBox,
    this.extractedUrlData,
  });

  factory ThreadResultData.fromJson(Map<String, dynamic> json) {
    return ThreadResultData(
      extractedUrlData: json['extractedUrlData'] != null
          ? ExtractedUrlResultData.fromJson(json['extractedUrlData'])
          : null,
      searchType: HomeSearchType.values.firstWhere(
        (e) => e.name == (json['searchType'] ?? 'general'),
        orElse: () => HomeSearchType.general,
      ),
      sourceImageDescription: json['sourceImageDescription'] ?? '',
      sourceImageLink: json['sourceImageLink'] ?? '',
      knowledgeGraph: json['knowledgeGraph'] != null
          ? KnowledgeGraphData.fromJson(json['knowledgeGraph'])
          : null,
      answerBox: json['answerBox'] != null
          ? AnswerBoxData.fromJson(json['answerBox'])
          : null,
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
      local: (json['local'] as List<dynamic>?)
              ?.map((e) => LocalResultData.fromJson(e))
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
        if (knowledgeGraph != null) 'knowledgeGraph': knowledgeGraph!.toJson(),
        if (answerBox != null) 'answerBox': answerBox!.toJson(),
        if (extractedUrlData != null)
          'extractedUrlData': extractedUrlData!.toJson(),
        'web': web.map((e) => e.toJson()).toList(),
        'searchType': searchType.name,
        'short_videos': shortVideos.map((e) => e.toJson()).toList(),
        'videos': videos.map((e) => e.toJson()).toList(),
        'news': news.map((e) => e.toJson()).toList(),
        'images': images.map((e) => e.toJson()).toList(),
        'local': local.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'userQuery': userQuery,
        'searchQuery': searchQuery,
        'answer': answer,
        'influence': influence.map((e) => e.toJson()).toList(),
        'isSearchMode': isSearchMode,
        'sourceImageDescription': sourceImageDescription,
        'sourceImageLink': sourceImageLink,
      };

  @override
  List<Object?> get props => [
        web,
        extractedUrlData,
        knowledgeGraph,
        answerBox,
        shortVideos,
        searchType,
        videos,
        news,
        images,
        local,
        createdAt,
        updatedAt,
        userQuery,
        searchQuery,
        answer,
        influence,
        isSearchMode,
        sourceImageDescription,
        sourceImageLink,
      ];
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

class KnowledgeGraphData extends Equatable {
  final String title;
  final String type;
  final String description;
  final List<HeaderImageData> headerImages;
  final List<MediaItemData> movies;
  final List<MediaItemData> moviesAndShows;
  final List<MediaItemData> tvShows;
  final List<MediaItemData> videoGames;
  final List<MediaItemData> books;

  const KnowledgeGraphData({
    required this.title,
    required this.type,
    required this.description,
    required this.headerImages,
    required this.movies,
    required this.moviesAndShows,
    required this.tvShows,
    required this.videoGames,
    required this.books,
  });

  factory KnowledgeGraphData.fromJson(Map<String, dynamic> json) {
    List<HeaderImageData> parseHeaderImages(List<dynamic>? data) {
      if (data == null) return [];
      return data.map((e) => HeaderImageData.fromJson(e)).toList();
    }

    List<MediaItemData> parseMediaList(List<dynamic>? data) {
      if (data == null) return [];
      return data.map((e) => MediaItemData.fromJson(e)).toList();
    }

    return KnowledgeGraphData(
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      headerImages: parseHeaderImages(json['header_images']),
      movies: parseMediaList(json['movies']),
      moviesAndShows: parseMediaList(json['movies_and_shows']),
      tvShows: parseMediaList(json['tv_shows']),
      videoGames: parseMediaList(json['video_games']),
      books: parseMediaList(json['books']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'type': type,
        'description': description,
        'header_images': headerImages.map((e) => e.toJson()).toList(),
        'movies': movies.map((e) => e.toJson()).toList(),
        'movies_and_shows': moviesAndShows.map((e) => e.toJson()).toList(),
        'tv_shows': tvShows.map((e) => e.toJson()).toList(),
        'video_games': videoGames.map((e) => e.toJson()).toList(),
        'books': books.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object> get props => [
        title,
        type,
        description,
        headerImages,
        movies,
        moviesAndShows,
        tvShows,
        videoGames,
        books
      ];
}

class HeaderImageData extends Equatable {
  final String image;
  final String source;

  const HeaderImageData({required this.image, required this.source});

  factory HeaderImageData.fromJson(Map<String, dynamic> json) =>
      HeaderImageData(
        image: json['image'] ?? '',
        source: json['source'] ?? '',
      );

  Map<String, dynamic> toJson() => {'image': image, 'source': source};

  @override
  List<Object> get props => [image, source];
}

class MediaItemData extends Equatable {
  final List<String>? extensions;
  final String image;

  const MediaItemData({this.extensions, required this.image});

  factory MediaItemData.fromJson(Map<String, dynamic> json) => MediaItemData(
        extensions: json['extensions'] != null
            ? List<String>.from(json['extensions'])
            : [],
        image: json['image'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'extensions': extensions,
        'image': image,
      };

  @override
  List<Object?> get props => [extensions, image];
}

class AnswerBoxData extends Equatable {
  final String type;
  final String title;
  final String answer;
  final String thumbnail;

  const AnswerBoxData({
    required this.type,
    required this.title,
    required this.answer,
    required this.thumbnail,
  });

  factory AnswerBoxData.fromJson(Map<String, dynamic> json) => AnswerBoxData(
        type: json['type'] ?? '',
        title: json['title'] ?? '',
        answer: json['answer'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'answer': answer,
        'thumbnail': thumbnail,
      };

  @override
  List<Object> get props => [type, title, answer, thumbnail];
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

  factory VideoResultData.fromJson(Map<String, dynamic> json) =>
      VideoResultData(
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

class ExtractedUrlResultData extends Equatable {
  final String title;
  final String link;
  final String thumbnail;
  final String snippet;

  const ExtractedUrlResultData({
    required this.title,
    required this.link,
    required this.thumbnail,
    required this.snippet,
  });

  factory ExtractedUrlResultData.fromJson(Map<String, dynamic> json) =>
      ExtractedUrlResultData(
        title: json['title'] ?? '',
        link: json['link'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        snippet: json['snippet'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'thumbnail': thumbnail,
        'snippet': snippet,
      };

  @override
  List<Object> get props => [title, link, thumbnail, snippet];
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

  factory ImageResultData.fromJson(Map<String, dynamic> json) =>
      ImageResultData(
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
  List<Object> get props => [url, snippet, title, similarity];
}

class ThreadSessionData extends Equatable {
  final String id;
  final List<ThreadResultData> results;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String email;
  final bool isIncognito;

  const ThreadSessionData({
    required this.id,
    required this.isIncognito,
    required this.email,
    required this.results,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ThreadSessionData.fromJson(Map<String, dynamic> json) {
    return ThreadSessionData(
      id: json['id'] ?? '',
      isIncognito: json['isIncognito'] ?? false,
      email: json['email'] ?? '',
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
        'isIncognito': isIncognito,
        'results': results.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  @override
  List<Object> get props =>
      [id, email, isIncognito, results, createdAt, updatedAt];
}

class LocalResultData extends Equatable {
  final int position;
  final String title;
  final String placeId;
  final String dataId;
  final String dataCid;
  final Map<String, dynamic> gpsCoordinates;
  final String placeIdSearch;
  final String providerId;
  final double rating;
  final int reviews;
  final String price;
  final String type;
  final List<String> types;
  final List<String> images;
  final String typeId;
  final List<String> typeIds;
  final String address;
  final String openState;
  final String hours;
  final Map<String, dynamic> operatingHours;
  final String phone;
  final String website;
  final String snippet;

  const LocalResultData({
    required this.position,
    required this.title,
    required this.placeId,
    required this.dataId,
    required this.dataCid,
    required this.gpsCoordinates,
    required this.placeIdSearch,
    required this.providerId,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.type,
    required this.types,
    required this.typeId,
    required this.typeIds,
    required this.address,
    required this.openState,
    required this.hours,
    required this.operatingHours,
    required this.phone,
    required this.website,
    required this.snippet,
    required this.images,
  });

  factory LocalResultData.fromJson(Map<String, dynamic> json) =>
      LocalResultData(
        position: json['position'] ?? 0,
        title: json['title'] ?? '',
        placeId: json['place_id'] ?? '',
        dataId: json['data_id'] ?? '',
        dataCid: json['data_cid'] ?? '',
        gpsCoordinates: json['gps_coordinates'] ?? {},
        placeIdSearch: json['place_id_search'] ?? '',
        providerId: json['provider_id'] ?? '',
        rating: (json['rating'] is int)
            ? (json['rating'] as int).toDouble()
            : (json['rating'] ?? 0.0),
        reviews: json['reviews'] ?? 0,
        price: json['price'] ?? '',
        type: json['type'] ?? '',
        types: json['types'] != null ? List<String>.from(json['types']) : [],
        images: json['images'] != null ? List<String>.from(json['images']) : [],
        typeId: json['type_id'] ?? '',
        typeIds:
            json['type_ids'] != null ? List<String>.from(json['type_ids']) : [],
        address: json['address'] ?? '',
        openState: json['open_state'] ?? '',
        hours: json['hours'] ?? '',
        operatingHours: json['operating_hours'] ?? {},
        phone: json['phone'] ?? '',
        website: json['website'] ?? '',
        snippet: json['snippet'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'position': position,
        'title': title,
        'place_id': placeId,
        'data_id': dataId,
        'data_cid': dataCid,
        'gps_coordinates': gpsCoordinates,
        'place_id_search': placeIdSearch,
        'provider_id': providerId,
        'rating': rating,
        'reviews': reviews,
        'price': price,
        'type': type,
        'types': types,
        'images': images,
        'type_id': typeId,
        'type_ids': typeIds,
        'address': address,
        'open_state': openState,
        'hours': hours,
        'operating_hours': operatingHours,
        'phone': phone,
        'website': website,
        'snippet': snippet,
      };

  @override
  List<Object> get props => [
        position,
        title,
        placeId,
        dataId,
        dataCid,
        gpsCoordinates,
        placeIdSearch,
        providerId,
        rating,
        reviews,
        price,
        type,
        types,
        images,
        typeId,
        typeIds,
        address,
        openState,
        hours,
        operatingHours,
        phone,
        website,
        snippet,
      ];
}
