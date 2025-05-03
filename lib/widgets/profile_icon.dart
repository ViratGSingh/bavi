import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:shimmer/shimmer.dart';

class CircularAvatarWithShimmer extends StatelessWidget {
  final String imageUrl;

  CircularAvatarWithShimmer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Color(0xFF8A2BE2),
            border: Border.all(
              color: Color(0xFF8A2BE2),
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
        ),
        ClipOval(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(
                color: Color(0xFFDFFF00),
                width: 2.0,
              ),
              shape: BoxShape.circle,
            ),
            child: imageUrl.isEmpty
                ? Icon(
                    Iconsax.frame_bold,
                    color: Color(0xFFDFFF00),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    useOldImageOnUrlChange: false,
                    
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      DefaultCacheManager().removeFile(url);
                      return Icon(
                      Iconsax.frame_bold,
                      color: Color(0xFFDFFF00),
                      size: 24,
                    );},
                  ),
          ),
        ),
      ],
    );
  }
}
