import 'package:bavi/home/widgets/video_scroll.dart';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ShortVideoThumbnails extends StatelessWidget {
  final List<ExtractedVideoInfo>? shortVideos;

  const ShortVideoThumbnails({Key? key, this.shortVideos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allEmpty = shortVideos != null && shortVideos!.every((e) => (e.videoData.thumbnailUrl).isEmpty);
    
    
    return Container(
      height: 168,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
            
            allEmpty
            ?
            List.generate(5, (_) => Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 90,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )) 
            :  List.generate(
             shortVideos?.length ?? 0, (index){
                bool hasValidThumbnail =
                    shortVideos?[index].videoData.thumbnailUrl != "";
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: hasValidThumbnail
                      ? Padding(
                        padding:  EdgeInsets.fromLTRB(0,0,10,0),
                        child: GestureDetector(
                            onTap: () async {
                              if (shortVideos?[index].platform == "instagram") {
                                // Navigator.of(context).push(
                                //   MaterialPageRoute(
                                //     builder: (context) => VideoPlayerPage(
                                //         videoList: [shortVideos![index]],
                                //         initialPosition: 0),
                                //   ),
                                // );
                        
                                String href =
                                    "${shortVideos?[index].videoData.videoUrl}/?igsh=a281dGZqd3lsZmIy";
                                final uri = Uri.parse(href);
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);                        
                                    
                              } 
                              else {
                                String href =
                                    shortVideos?[index].videoData.videoUrl ?? "";
                                final uri = Uri.parse(href);
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  key: ValueKey(shortVideos?[index].videoData.thumbnailUrl),
                                  width: 90,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      shortVideos?[index].videoData.thumbnailUrl ?? "",
                                      fit: BoxFit.cover,
                                      height: 160,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Shimmer.fromColors(
                                          baseColor: Colors.grey.shade300,
                                          highlightColor: Colors.grey.shade100,
                                          child: Container(
                                            width: 100,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: Colors.grey,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(5,5,0,0),
                                  child: Icon( shortVideos?[index].videoData.videoUrl.contains("instagram")==true?Iconsax.instagram_bold:Iconsax.youtube_bold, size: 16, color: Colors.white,),
                                )
                              ],
                            ),
                          ),
                      )
                      : null,
                );
              },
            ),
          
        ),
      ),
    );
  }
}

class LongVideoThumbnails extends StatelessWidget {
  final List<ExtractedVideoInfo>? longVideos;

  const LongVideoThumbnails({Key? key, this.longVideos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allEmpty = longVideos != null && longVideos!.every((e) => (e.videoData.thumbnailUrl).isEmpty);
    
    return Container(
      height: 160,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: 
      
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
            allEmpty
            ?
            List.generate(5, (_) => Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 260,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )) 
            :  List.generate(
             longVideos?.length ?? 0, (index)  {
                bool hasValidThumbnail =
                    longVideos?[index].videoData.thumbnailUrl != "";
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: hasValidThumbnail
                      ? Padding(
                        padding:  EdgeInsets.fromLTRB(0,5,10,0),
                        child: GestureDetector(
                            onTap: () async {
                              // if (longVideos?[index].platform == "instagram") {
                              //   Navigator.of(context).push(
                              //     MaterialPageRoute(
                              //       builder: (context) => VideoPlayerPage(
                              //           videoList: [longVideos![index]],
                              //           initialPosition: 0),
                              //     ),
                              //   );
                              // } else {
                                String href =
                                    longVideos?[index].videoData.videoUrl ?? "";
                                final uri = Uri.parse(href);
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              //}
                            },
                            child: Container(
                              key: ValueKey(longVideos?[index].videoData.thumbnailUrl),
                              //width: 160,
                              //height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                //color: Colors.black
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  longVideos?[index].videoData.thumbnailUrl ?? "",
                                  fit: BoxFit.cover,
                                  height: 160,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Shimmer.fromColors(
                                      baseColor: Colors.grey.shade300,
                                      highlightColor: Colors.grey.shade100,
                                      child: Container(
                                        width: 220,
                                        height: 160,
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      )
                      : null,
                );
              },
            ),
          
        ),
      ),
    );
  }
}


class SearchResultThumbnails extends StatelessWidget {
  final List<ExtractedResultInfo>? searchResults;

  const SearchResultThumbnails({Key? key, this.searchResults}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final allEmpty = searchResults != null && searchResults!.every((e) => (e.thumbnailUrl ?? "").isEmpty);
    return Container(
      height: 160,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: allEmpty
            ? List.generate(5, (_) => Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ))
            : List.generate(searchResults?.length ?? 0, (index) {
              String updthumbnailUrl = searchResults?[index].thumbnailUrl ?? "";
              if (updthumbnailUrl.startsWith("/")) {
                final baseUri = Uri.tryParse(searchResults?[index].url ?? "");
                if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
                  updthumbnailUrl = "${baseUri.scheme}://${baseUri.host}$updthumbnailUrl";
                }
              }
              bool hasValidThumbnail =
                  updthumbnailUrl != "";
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: hasValidThumbnail
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                        child: GestureDetector(
                          onTap: () async {
                            String href = searchResults?[index].url ?? "";
                            final uri = Uri.parse(href); 
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          },
                          child: Container(
                            key: ValueKey(updthumbnailUrl),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                updthumbnailUrl,
                                height: 160,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Container(
                                      width: 220,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              );
            }),
        ),
      ),
    );
  }
}
