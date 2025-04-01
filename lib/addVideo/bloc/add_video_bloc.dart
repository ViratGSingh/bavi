import 'dart:convert';
import 'dart:io';
import 'package:bavi/addVideo/bloc/add_video_state.dart';
import 'package:bavi/models/collection.dart';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aws_client/s3_2006_03_01.dart';

part 'add_video_event.dart';

class AddVideoBloc extends Bloc<AddVideoEvent, AddVideoState> {
  final http.Client httpClient;
  AddVideoBloc({required this.httpClient}) : super(AddVideoState()) {
    on<AddVideoExtract>(_extractVideo);
    on<AddVideoReset>(_resetPage);
    on<AddVideoRedirect>(_redirectToVideo);
    on<AddVideoFetchCollections>(_fetchCollections);
    on<AddVideoUpdateCollections>(_addVideoCollectionToUser);
    on<AddVideoCheckLink>(_checkLink);
    on<AddVideoInitiateMixpanel>(_initMixpanel);
  }
  ExtractedVideoInfo? extractedVideoInfo;

  String instagramTutorialVideoUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/videos/save_instagram_video.mp4";
  String youtubeTutorialVideoUrl =
      "https://bavi.s3.ap-south-1.amazonaws.com/videos/save_youtube_video.mp4";

  Future<void> _checkLink(
      AddVideoCheckLink event, Emitter<AddVideoState> emit) async {
    String link = event.link;
    bool isValidUrl = Uri.tryParse(link)?.hasAbsolutePath ?? false;

    if (!isValidUrl) {
      emit(state.copyWith(isValidLink: false));
      return;
    }

    if (link.contains("instagram") && link.contains("reel")) {
      emit(state.copyWith(isValidLink: true));
    } else if (link.contains("youtube") && link.contains("shorts")) {
      emit(state.copyWith(isValidLink: true));
    } else {
      emit(state.copyWith(isValidLink: false));
    }
  }

  late Mixpanel mixpanel;
  Future<void> _initMixpanel(
      AddVideoInitiateMixpanel event, Emitter<AddVideoState> emit) async {
    // initialize Mixpanel
    mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
  }

  //Fetch Collections
  Future<void> _fetchCollections(
      AddVideoFetchCollections event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.initialLoading));
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userEmaildId = prefs.getString("email");

    // Reference to the Firestore collection "users"
    final CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('users');

    // Query the users collection for a document with the matching email
    final QuerySnapshot querySnapshot = await usersCollection
        .where('email', isEqualTo: userEmaildId)
        .limit(1)
        .get();

    // Check if any documents were found
    if (querySnapshot.docs.isEmpty) {
      throw Exception('User not found');
    }

    // Get the first document (since we limited the query to 1)
    final DocumentSnapshot userDoc = querySnapshot.docs.first;

    // Check if the "video_collections" field exists in the document
    if (userDoc.exists && userDoc.data() != null) {
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      if (userData.containsKey('video_collections')) {
        // Extract the "video_collections" field from the user document
        final List<dynamic> videoCollectionsData =
            userData['video_collections'] as List<dynamic>;

        // Parse the data into a list of VideoCollectionInfo objects
        final List<VideoCollectionInfo> videoCollections = videoCollectionsData
            .map((collectionData) => VideoCollectionInfo.fromJson(
                  collectionData as Map<String, dynamic>,
                ))
            .toList();
        emit(state.copyWith(
            collectionsInfo: videoCollections, status: AddVideoStatus.idle));
      } else {
        // If "video_collections" does not exist, emit an empty list
        emit(state.copyWith(collectionsInfo: []));
      }
    } else {
      // If the document data is null, emit an empty list
      emit(state.copyWith(collectionsInfo: []));
    }
  }

  //Download and cache video
  Future<File?> downloadAndCacheVideo(
      String videoUrl, String videoId, String platform) async {
    try {
      // Use flutter_cache_manager to download and cache the video
      final file =
          await DefaultCacheManager().getSingleFile(videoUrl, key: videoUrl);

      print('Video downloaded and cached at: ${file.path}');
      return file;
    } catch (e) {
      print('Error downloading or caching video: $e');
      return null;
    }
  }

  Future<File?> downloadAndCacheThumbnail(
      String thumbnailUrl, String videoId, String platform) async {
    try {
      // Use flutter_cache_manager to download and cache the thumbnail
      final file = await DefaultCacheManager().getSingleFile(
        thumbnailUrl,
        key: thumbnailUrl, // Unique cache key
      );

      print('Thumbnail downloaded and cached at: ${file.path}');
      return file;
    } catch (e) {
      print('Error downloading or caching thumbnail: $e');
      return null;
    }
  }

//Upload video to aws s3 and get its url
  String bucketName = 'bavi';
  String folderName = 'videos';
  String region = 'ap-south-1'; // Replace with your bucket's region

  ValueNotifier<double> videoProgress = ValueNotifier(0);
  Future<String?> streamVideoToS3(
      String videoUrl, String platform, String videoId) async {
    videoProgress.value = 0;
    // AWS S3 Configuration
    String region = dotenv.get('AWS_REGION');
    String bucketName = dotenv.get('AWS_BUCKET_NAME');
    String folderName = dotenv.get('AWS_VID_FOLDER_NAME');
    String accessKey = dotenv.get('AWS_ACCESS_KEY');
    String secretKey = dotenv.get('AWS_SECRET_KEY');

    // Initialize the S3 client
    final s3 = S3(
      region: region,
      credentials: AwsClientCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
      ),
    );

    try {
      // Step 1: Create a temporary file to store the download
      final tempDir = await Directory.systemTemp.createTemp('video_download');
      final tempFile = File('${tempDir.path}/temp_video.mp4');

      // Step 2: Download the file with progress tracking
      final request = http.Request('GET', Uri.parse(videoUrl));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Failed to download video: ${streamedResponse.statusCode}');
      }

      // Get total size for progress calculation
      final totalBytes = streamedResponse.contentLength ?? 0;
      var downloadedBytes = 0;

      // Create file sink
      final fileSink = tempFile.openWrite();

      // Download with progress tracking
      await for (final chunk in streamedResponse.stream) {
        fileSink.add(chunk);
        downloadedBytes += chunk.length;
        final progress =
            totalBytes > 0 ? (downloadedBytes / totalBytes) * 100 : 0;
        print('Download progress: ${progress.toStringAsFixed(2)}%');
        videoProgress.value = (downloadedBytes / totalBytes).toDouble();
      }

      await fileSink.flush();
      await fileSink.close();

      // Generate a unique file name for the video
      String fileName = '${platform}_$videoId.mp4';
      String s3Key = '$folderName/$fileName'; // Full S3 key (path)

      // Step 3: Upload the file to S3
      await s3.putObject(
        bucket: bucketName,
        key: s3Key,
        body: await tempFile.readAsBytes(),
        contentType: 'video/mp4',
      );

      // Step 4: Clean up the temporary file
      await tempFile.delete();
      await tempDir.delete();

      videoProgress.value = 1;

      print('Video uploaded successfully to folder: $folderName');

      // Step 5: Construct the public URL of the uploaded video
      final uploadedVideoUrl =
          'https://$bucketName.s3.$region.amazonaws.com/$s3Key';
      print('Uploaded video URL: $uploadedVideoUrl');

      return uploadedVideoUrl;
    } catch (e) {
      print('Error streaming video to S3: $e');
      return null;
    }
  }

  //upload thumbnail to the s3 and get its url
  ValueNotifier<double> imageProgress = ValueNotifier(0);

  Future<String?> streamImageToS3(
      String imageUrl, String platform, String videoId) async {
    imageProgress.value = 0;
    // AWS S3 Configuration
    String region = dotenv.get('AWS_REGION');
    String bucketName = dotenv.get('AWS_BUCKET_NAME');
    String folderName = dotenv.get('AWS_IMG_FOLDER_NAME');
    String accessKey = dotenv.get('AWS_ACCESS_KEY');
    String secretKey = dotenv.get('AWS_SECRET_KEY');

    // Initialize the S3 client
    final s3 = S3(
      region: region,
      credentials: AwsClientCredentials(
        accessKey: accessKey,
        secretKey: secretKey,
      ),
    );

    try {
      // Detect content type from URL
      String fileExtension = 'jpg'; // Default
      String contentType = 'image/jpeg'; // Default
      final urlExtension = path.extension(imageUrl).toLowerCase();
      if (urlExtension.isNotEmpty) {
        fileExtension = urlExtension.replaceFirst('.', '');
        switch (fileExtension) {
          case 'png':
            contentType = 'image/png';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          case 'jpeg':
          case 'jpg':
          default:
            contentType = 'image/jpeg';
            fileExtension = 'jpg';
            break;
        }
      }

      // Generate file name
      String fileName = '${platform}_$videoId.$fileExtension';
      String s3Key = '$folderName/$fileName';

      // Get total size with HEAD request first (for better error handling)
      final headResponse = await http.head(Uri.parse(imageUrl));
      if (headResponse.statusCode != 200) {
        throw Exception('Failed to access image: ${headResponse.statusCode}');
      }

      // Get content length for progress calculation
      final totalBytes =
          int.parse(headResponse.headers['content-length'] ?? '0');

      // Create a download request for streaming
      final request = http.Request('GET', Uri.parse(imageUrl));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
            'Failed to download image: ${streamedResponse.statusCode}');
      }

      // Track download progress
      final List<int> bytes = [];
      var downloadedBytes = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;

        // Calculate download progress (0-50%)
        final downloadProgress =
            totalBytes > 0 ? (downloadedBytes / totalBytes) * 0.5 : 0.0;

        print(
            'Image download progress: ${(downloadProgress * 100).toStringAsFixed(1)}%');
        imageProgress.value = downloadProgress;
      }

      // Convert List<int> to Uint8List for S3
      final Uint8List uploadData = Uint8List.fromList(bytes);

      // Upload the image directly to S3
      await s3.putObject(
        bucket: bucketName,
        key: s3Key,
        body: uploadData, // Use Uint8List here
        contentType: contentType,
      );

      print(
          'Image uploaded successfully to folder: $folderName with format: $contentType');

      // Construct the public URL
      final uploadedImageUrl =
          'https://$bucketName.s3.$region.amazonaws.com/$s3Key';
      print('Uploaded image URL: $uploadedImageUrl');
      imageProgress.value = 1;
      return uploadedImageUrl;
    } catch (e) {
      print('Error streaming image to S3: $e');
      return null;
    }
  }

  // Add Collection
  Future<void> _addVideoCollectionToUser(
      AddVideoUpdateCollections event, Emitter<AddVideoState> emit) async {
    mixpanel.timeEvent("save_video");
    emit(state.copyWith(status: AddVideoStatus.loading));
    //Save video and thumbnail and replace with its urls
    //Download the video and save it in s3
    if (event.platform == "instagram") {
      await backgroundExtractIgInfo(event.videoId);
    } else if (event.platform == "youtube") {
      await backgroundExtractYtInfo(event.videoId);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userEmaildId = prefs.getString("email");
    await prefs.setBool('isOnboarded', true);
    try {
      // Reference to the Firestore collection "users"
      final CollectionReference usersCollection =
          FirebaseFirestore.instance.collection('users');

      // Query the users collection for a document with the matching email
      final QuerySnapshot querySnapshot = await usersCollection
          .where('email', isEqualTo: userEmaildId)
          .limit(1)
          .get();

      // Check if any documents were found
      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found');
      }

      // Get the first document (since we limited the query to 1)
      final DocumentSnapshot userDoc = querySnapshot.docs.first;

      // Convert the new list of collections to a list of maps
      final List<Map<String, dynamic>> newCollectionsMap =
          event.collections.map((collection) => collection.toJson()).toList();

      // Update the user document with the new list of video collections
      await usersCollection.doc(userDoc.id).update({
        'video_collections': newCollectionsMap,
      });

      print('New collections added successfully');
    } catch (e) {
      print('Error adding video collections: $e');
      // Optionally, you can rethrow the error or handle it differently
      // rethrow;
    }

    mixpanel.track("save_video");

    emit(state.copyWith(
        status: AddVideoStatus.idle,
        extractedVideoInfo: null,
        videoId: null,
        collectionsInfo: null));

    //await Clipboard.setData(ClipboardData(text: ""));
    navService.goTo('/home');
  }

  Future<void> _resetPage(
      AddVideoReset event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(
      status: AddVideoStatus.idle,
      extractedVideoInfo: null,
      videoId: "",
      platform: "",
    ));
  }

  Future<void> _redirectToVideo(
      AddVideoRedirect event, Emitter<AddVideoState> emit) async {
    emit(state.copyWith(status: AddVideoStatus.success));
  }

  String? extractInstagramId(String url) {
    Uri uri = Uri.parse(url);
    List<String> segments = uri.pathSegments;
    return segments.length > 1 ? segments[1] : null;
  }

  String? extractYouTubeShortsId(String url) {
    Uri uri = Uri.parse(url);
    List<String> segments = uri.pathSegments;

    // Check if the URL contains the 'shorts' segment
    if (segments.contains('shorts') && segments.length > 1) {
      // The video ID is the segment immediately after 'shorts'
      return segments[segments.indexOf('shorts') + 1];
    }

    return null; // Return null if the URL is not a valid YouTube Shorts URL
  }

  bool isBackupExtractDone = false;
  Future<void> _extractVideo(
      AddVideoExtract event, Emitter<AddVideoState> emit) async {
    if (event.isOnboarding == false) {
      mixpanel.timeEvent("extract_video");
    }
    emit(state.copyWith(status: AddVideoStatus.loading));
    String videoLink = event.link;
    String videoId = "";
    String platform = "";
    //Check link
    if (videoLink.contains("instagram")) {
      platform = "instagram";
      String? igVideoId = extractInstagramId(videoLink);
      if (igVideoId != null) {
        videoId = igVideoId;
        await checkBackupVidInfo(igVideoId, "instagram");
        if (extractedVideoInfo == null) {
          await fetchInstagramVideoInfo(igVideoId);
        } else {
          isBackupExtractDone = true;
        }
      }
    } else if (videoLink.contains("youtube")) {
      platform = "youtube";
      String? ytVideoId = extractInstagramId(videoLink);
      if (ytVideoId != null) {
        videoId = ytVideoId;
        await checkBackupVidInfo(ytVideoId, "youtube");
        if (extractedVideoInfo == null) {
          await fetchYoutubeShortInfo(ytVideoId);
        } else {
          isBackupExtractDone = true;
        }
      }
    }
    //fetch info
    //fetchInstagramVideoInfo();
    if (event.isOnboarding == false) {
      mixpanel.track("extract_video");
    }
    emit(state.copyWith(
        status: AddVideoStatus.success,
        extractedVideoInfo: extractedVideoInfo,
        videoId: videoId,
        platform: platform));
  }

  Future<void> checkBackupVidInfo(String videoId, String platform) async {
    extractedVideoInfo = null;
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
      extractedVideoInfo = ExtractedVideoInfo.fromJson(data["data"]);
      await db.collection("videos").doc(querySnapshot.docs.first.id).set({
        'total_extracts': data["total_extracts"] + 1,
        'updated_at': Timestamp.now()
      }, SetOptions(merge: true)); // Merge to update only specified fields
    }
  }

  Future<void> fetchInstagramVideoInfo(String id) async {
    final url = Uri.https(
      dotenv.get("IG_RAPID_API_HOST"),
      '/v1/post_info',
      {'code_or_id_or_url': id, 'include_insights': 'true'},
    );

    final headers = {
      'x-rapidapi-key': dotenv.get("RAPID_API_KEY"),
      'x-rapidapi-host': dotenv.get("IG_RAPID_API_HOST"),
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);

      print('Data: ${respData["user"]}');
      //User Data
      UserData userData = UserData(
          username: respData["data"]["user"]["username"],
          fullname: respData["data"]["user"]["full_name"],
          profilePicUrl: respData["data"]["user"]["profile_pic_url"]);

      //Video Data
      VideoData videoData = VideoData(
        thumbnailUrl: respData["data"]["thumbnail_url"],
        videoUrl: respData["data"]["video_url"],
      );

      extractedVideoInfo = ExtractedVideoInfo(
          searchContent:
              "${userData.username}, ${userData.fullname}, ${respData["data"]["caption"]["text"]}",
          caption: respData["data"]["caption"]["text"],
          userData: userData,
          videoData: videoData);
    } else {
      // Handle error
      print('Failed to load data: ${response.statusCode}');
    }
  }

  Future<void> backgroundExtractYtInfo(String id) async {
    String? videoUrl;
    String? imageUrl;
    if (isBackupExtractDone == true) {
      videoUrl = extractedVideoInfo!.videoData.videoUrl;
      imageUrl = extractedVideoInfo!.videoData.thumbnailUrl;
    }else{
      videoUrl = await streamVideoToS3(
        extractedVideoInfo!.videoData.videoUrl, "youtube", id);
      imageUrl = await streamImageToS3(
        extractedVideoInfo!.videoData.thumbnailUrl, "youtube", id);
        }
    if (videoUrl != null && imageUrl != null) {
      ExtractedVideoInfo updatedVideoInfo = ExtractedVideoInfo(
          searchContent: extractedVideoInfo!.searchContent,
          caption: extractedVideoInfo!.caption,
          userData: extractedVideoInfo!.userData,
          videoData: VideoData(thumbnailUrl: imageUrl, videoUrl: videoUrl));

      Map<String, dynamic> extractedData = {
        "videoId": id,
        "platform": "youtube",
        "data": updatedVideoInfo?.toJson() ?? {},
        "total_extracts": 1,
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now()
      };
      if(isBackupExtractDone==false){
        await backupExtractedData(extractedData, id, "youtube");
      }
      downloadAndCacheVideo(videoUrl, id, "youtube");
      downloadAndCacheThumbnail(imageUrl, id, "youtube");
    }

    print('Data: $extractedVideoInfo');
  }

  Future<void> backgroundExtractIgInfo(String id) async {
    String? videoUrl;
    String? imageUrl;
    if (isBackupExtractDone == true) {
      videoUrl = extractedVideoInfo!.videoData.videoUrl;
      imageUrl = extractedVideoInfo!.videoData.thumbnailUrl;
    } else {
      // Generate a unique file name for the video
      videoUrl = await streamVideoToS3(
          extractedVideoInfo!.videoData.videoUrl, "instagram", id);
      imageUrl = await streamImageToS3(
          extractedVideoInfo!.videoData.thumbnailUrl, "instagram", id);
    }
    if (videoUrl != null && imageUrl != null) {
      ExtractedVideoInfo updatedVideoInfo = ExtractedVideoInfo(
          searchContent: extractedVideoInfo!.searchContent,
          caption: extractedVideoInfo!.caption,
          userData: extractedVideoInfo!.userData,
          videoData: VideoData(thumbnailUrl: imageUrl, videoUrl: videoUrl));

      Map<String, dynamic> extractedData = {
        "videoId": id,
        "platform": "instagram",
        "data": updatedVideoInfo?.toJson() ?? {},
        "total_extracts": 1,
        "created_at": Timestamp.now(),
        "updated_at": Timestamp.now()
      };
      if(isBackupExtractDone==false){
        await backupExtractedData(extractedData, id, "instagram");
      }
      print('Data: $extractedVideoInfo');
      downloadAndCacheVideo(videoUrl, id, "instagram");
      downloadAndCacheThumbnail(imageUrl, id, "instagram");
    }
  }

  Future<void> backupExtractedData(Map<String, dynamic> extractedData,
      String videoId, String platform) async {
    //Save Extracted Reel Info
    FirebaseFirestore db = FirebaseFirestore.instance;
    //Check if a document with the same email exists
    QuerySnapshot querySnapshot = await db
        .collection("videos")
        .where('videoId', isEqualTo: videoId)
        .where('platform', isEqualTo: platform)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Document with the same id exists, update it
      String documentId = querySnapshot.docs.first.id;
      int totalExtracts = querySnapshot.docs.first.get("total_extracts") ?? 0;
      await db.collection("videos").doc(documentId).set(
          {'total_extracts': totalExtracts + 1, 'updated_at': Timestamp.now()},
          SetOptions(merge: true)); // Merge to update only specified fields
    } else {
      // Add a new document with a generated ID
      await db.collection("videos").add(extractedData);
    }
  }

  Future<void> fetchYoutubeShortInfo(String id) async {
    final url = Uri.https(
      dotenv.get("YT_RAPID_API_HOST"),
      '/v2/video/details',
      {'videoId': id},
    );

    final headers = {
      'x-rapidapi-key': dotenv.get("RAPID_API_KEY"),
      'x-rapidapi-host': dotenv.get("YT_RAPID_API_HOST"),
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Successfully fetched data
      final data = response.body;
      Map<String, dynamic> respData = jsonDecode(data);

      //User Data
      UserData userData = UserData(
          username: respData["channel"]["handle"],
          fullname: respData["channel"]["name"],
          profilePicUrl: respData["channel"]["avatar"][0]["url"]);

      //Video Data
      VideoData videoData = VideoData(
        thumbnailUrl: respData["thumbnails"][4]["url"],
        videoUrl: respData["videos"]["items"][0]["url"],
      );

      extractedVideoInfo = ExtractedVideoInfo(
          searchContent:
              "${userData.username}, ${userData.fullname}, ${respData["title"]}, ${respData["description"]}",
          caption: respData["description"],
          userData: userData,
          videoData: videoData);

      //Save video and thumbnail and replace with its urls
      //Download the video and save it in s3
      backgroundExtractYtInfo(id);
    } else {
      // Handle error
      print('Failed to load data: ${response.statusCode}');
    }
  }
}
