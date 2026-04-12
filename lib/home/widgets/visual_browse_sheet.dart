import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bavi/home/widgets/visual_browse_webview.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/services/drissy_engine.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;

// ─── Data / State ───────────────────────────────────────────────────────────

enum _VBItemStatus { analyzing, accepted, rejected }

class _VBItem {
  final VisualBrowseImageData data;
  _VBItemStatus status;
  Uint8List? imageBytes; // decoded thumbnail bytes

  _VBItem(this.data, this.status);
}

// ─── Main Sheet Widget ───────────────────────────────────────────────────────

class VisualBrowseSheet extends StatefulWidget {
  final void Function(String query, List<VisualBrowseResultData> images)? onComplete;
  const VisualBrowseSheet({super.key, this.onComplete});

  @override
  State<VisualBrowseSheet> createState() => _VisualBrowseSheetState();
}

class _VisualBrowseSheetState extends State<VisualBrowseSheet> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<_VBItem> _items = [];
  bool _isBrowsing = false;
  bool _isDone = false;
  int _totalImages = 0;
  int _processedCount = 0;
  bool _visionUnavailable = false;
  String _statusText = '';

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Entry point: user submits query ──────────────────────────────────────

  Future<void> _startBrowse() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _items.clear();
      _isBrowsing = true;
      _isDone = false;
      _totalImages = 0;
      _processedCount = 0;
      _visionUnavailable = false;
      _statusText = 'Opening image search...';
    });

    // 1. Open WebView full-screen (above the sheet) to extract images
    final List<VisualBrowseImageData>? extracted =
        await Navigator.of(context, rootNavigator: true)
            .push<List<VisualBrowseImageData>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VisualBrowseWebView(query: query),
      ),
    );

    if (!mounted) return;

    if (extracted == null || extracted.isEmpty) {
      setState(() {
        _isBrowsing = false;
        _statusText = 'No images found. Try a different query.';
      });
      return;
    }

    setState(() {
      _totalImages = extracted.length;
      _statusText = 'Analysing images with vision...';
    });

    // 2. Check if vision model is available
    final engine = DrissyEngine();
    final visionReady = engine.isLoaded && engine.isVisionLoaded;

    if (!visionReady) {
      setState(() => _visionUnavailable = true);
    }

    // 3. Process images sequentially
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < extracted.length; i++) {
      if (!mounted) break;
      final img = extracted[i];

      // Decode bytes early for display
      Uint8List? bytes;
      try {
        bytes = await _resolveThumbnailBytes(img.thumbnailDataUri, i);
      } catch (_) {}

      final item = _VBItem(img, _VBItemStatus.analyzing)..imageBytes = bytes;

      setState(() {
        _items.add(item);
        _statusText = 'Scanning ${i + 1} of ${extracted.length}...';
      });

      if (!mounted) break;

      bool isMatch = true; // default: show if vision unavailable

      if (visionReady && bytes != null) {
        try {
          final tempFile =
              File('${tempDir.path}/vb_img_$i.jpg');
          await tempFile.writeAsBytes(bytes);

          String response = '';
          final stream = engine.chat(
            systemMessage:
                'You are a visual relevance checker. Answer only "yes" or "no". No extra text.',
            conversationMessages: [
              {
                'role': 'user',
                'content':
                    'Does this image match the description: "$query"? Answer only yes or no.'
              }
            ],
            imagePath: tempFile.path,
          );
          await for (final token in stream) {
            response += token;
            if (response.length > 20) break; // enough to determine yes/no
          }
          isMatch = response.toLowerCase().trim().startsWith('yes');

          // Clean up temp file
          try { await tempFile.delete(); } catch (_) {}
        } catch (e) {
          print('VisualBrowseSheet: vision error for image $i: $e');
          isMatch = true; // show on error
        }
      }

      if (!mounted) break;

      setState(() {
        item.status = isMatch ? _VBItemStatus.accepted : _VBItemStatus.rejected;
        _processedCount = i + 1;
      });
    }

    if (!mounted) return;
    final accepted = _items.where((it) => it.status == _VBItemStatus.accepted).toList();
    setState(() {
      _isBrowsing = false;
      _isDone = true;
      _statusText = visionReady
          ? 'Found ${accepted.length} matching image${accepted.length == 1 ? '' : 's'}'
          : 'Showing all ${extracted.length} images';
    });

    // Notify the thread with the final results
    if (widget.onComplete != null) {
      final query = _queryController.text.trim();
      final resultData = accepted.map((it) => VisualBrowseResultData(
        thumbnailDataUri: it.data.thumbnailDataUri,
        title: it.data.title,
        sourceLink: it.data.sourceLink,
      )).toList();
      widget.onComplete!(query, resultData);
    }
  }

  // ── Decode thumbnail bytes ────────────────────────────────────────────────

  Future<Uint8List> _resolveThumbnailBytes(String src, int index) async {
    if (src.startsWith('data:image/')) {
      final base64Part = src.split(',').last;
      return base64Decode(base64Part);
    } else if (src.startsWith('http')) {
      final response = await http.get(Uri.parse(src)).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200) return response.bodyBytes;
    }
    throw Exception('Cannot resolve thumbnail: $src');
  }

  // ── Open fullscreen lightbox ─────────────────────────────────────────────

  void _openLightbox(List<_VBItem> items, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _ImageLightbox(items: items, initialIndex: initialIndex);
        },
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearchRow(),
          if (_visionUnavailable) _buildVisionBanner(),
          if (_statusText.isNotEmpty) _buildStatusRow(),
          Expanded(child: _buildResultsGrid()),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2BE2), Color(0xFFAB47BC)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_search_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Visual Browse',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _queryController,
                focusNode: _focusNode,
                enabled: !_isBrowsing,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _startBrowse(),
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Poppins',
                  color: Color(0xFF111827),
                ),
                decoration: const InputDecoration(
                  hintText: 'Describe images to find...',
                  hintStyle: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Color(0xFF9CA3AF), size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isBrowsing ? null : _startBrowse,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isBrowsing
                    ? const LinearGradient(
                        colors: [Color(0xFFD1C4E9), Color(0xFFE1BEE7)])
                    : const LinearGradient(
                        colors: [Color(0xFF8A2BE2), Color(0xFFAB47BC)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isBrowsing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF856404), size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Vision model not loaded — showing all images without filtering',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF856404),
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          if (_isBrowsing) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: const Color(0xFF8A2BE2).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_isDone)
            const Icon(Icons.check_circle_rounded,
                size: 14, color: Color(0xFF10B981)),
          if (_isDone) const SizedBox(width: 6),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: _isDone
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
          if (_isBrowsing && _totalImages > 0)
            Text(
              '$_processedCount / $_totalImages',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A2BE2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid() {
    final visibleItems = _items
        .where((it) => it.status != _VBItemStatus.rejected)
        .toList();

    if (visibleItems.isEmpty && !_isBrowsing && _statusText.isEmpty) {
      return _buildEmptyState();
    }

    if (visibleItems.isEmpty && _isBrowsing) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
      );
    }

    if (visibleItems.isEmpty && _isDone) {
      return _buildNoMatchState();
    }

    // When done, show premium album view
    if (_isDone) {
      return  _buildAlbumView(visibleItems);
    }

    // While scanning, show 2-col grid with scanning cards
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: visibleItems.length,
        itemBuilder: (context, index) {
          final item = visibleItems[index];
          return _VisualBrowseImageCard(item: item, key: ValueKey(item.data.thumbnailDataUri));
        },
      ),
    );
  }

  // ── Album view shown when done ────────────────────────────────────────────

  Widget _buildAlbumView(List<_VBItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Album header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A2BE2), Color(0xFFAB47BC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      '${items.length} image${items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Tap to view',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
        // Album grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bytes = item.imageBytes;
                return GestureDetector(
                  onTap: () => _openLightbox(items, index),
                  child: Hero(
                    tag: 'vb_img_${item.data.thumbnailDataUri.hashCode}_$index',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFFF3F4F6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A2BE2).withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: bytes != null
                            ? Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.image_outlined,
                                    color: Color(0xFFD1D5DB), size: 28),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.image_search_rounded,
                size: 36, color: Color(0xFF8A2BE2)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search for images visually',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Describe what you\'re looking for and the AI will find and verify matching images',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text(
            'No matching images found',
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different description',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image Card (scanning state) ─────────────────────────────────────────────

class _VisualBrowseImageCard extends StatefulWidget {
  final _VBItem item;
  const _VisualBrowseImageCard({required this.item, super.key});

  @override
  State<_VisualBrowseImageCard> createState() => _VisualBrowseImageCardState();
}

class _VisualBrowseImageCardState extends State<_VisualBrowseImageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildImageArea()),
              _buildInfoArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final isAnalyzing = widget.item.status == _VBItemStatus.analyzing;
    final bytes = widget.item.imageBytes;

    Widget imageWidget;
    if (bytes != null) {
      imageWidget = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    } else {
      imageWidget = _imagePlaceholder();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        if (isAnalyzing) _buildScanningOverlay(),
        if (isAnalyzing)
          Positioned(
            top: 8,
            right: 8,
            child: _ScanningBadge(),
          ),
        if (widget.item.status == _VBItemStatus.accepted)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child:
                  const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        final scanY = _scanAnimation.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Shimmer base
            Shimmer.fromColors(
              baseColor: Colors.purple.withValues(alpha: 0.08),
              highlightColor: Colors.purple.withValues(alpha: 0.20),
              child: Container(color: Colors.white),
            ),
            // Scan line
            Positioned(
              left: 0,
              right: 0,
              top: scanY * (double.infinity.isInfinite ? 0 : 0), // workaround
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final top = scanY * constraints.maxHeight;
                  return Stack(
                    children: [
                      Positioned(
                        top: top - 30,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF8A2BE2).withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: top,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF8A2BE2).withValues(alpha: 0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF3F4F6),
      highlightColor: const Color(0xFFE5E7EB),
      child: Container(color: Colors.white),
    );
  }

  Widget _buildInfoArea() {
    final title = widget.item.data.title;
    final isAnalyzing = widget.item.status == _VBItemStatus.analyzing;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: isAnalyzing
          ? Shimmer.fromColors(
              baseColor: const Color(0xFFF3F4F6),
              highlightColor: const Color(0xFFE5E7EB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                      height: 1.3,
                    ),
                  ),
                if (widget.item.data.sourceLink.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _domainFromUrl(widget.item.data.sourceLink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _domainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

// ─── Scanning badge ───────────────────────────────────────────────────────────

class _ScanningBadge extends StatefulWidget {
  @override
  State<_ScanningBadge> createState() => _ScanningBadgeState();
}

class _ScanningBadgeState extends State<_ScanningBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF8A2BE2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A2BE2).withValues(alpha: 0.4),
              blurRadius: 8,
            )
          ],
        ),
        child: const Text(
          'AI',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Fullscreen Image Lightbox ────────────────────────────────────────────────

class _ImageLightbox extends StatefulWidget {
  final List<_VBItem> items;
  final int initialIndex;

  const _ImageLightbox({required this.items, required this.initialIndex});

  @override
  State<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<_ImageLightbox>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _fadeController.reverse();
    if (mounted) Navigator.pop(context);
  }

  String _domainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0015),
                const Color(0xFF12002A),
                const Color(0xFF0D0D1F),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Ambient purple glow behind images
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFF4A148C).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // PageView
              PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (ctx, index) {
                  final it = widget.items[index];
                  final bytes = it.imageBytes;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      topPad + 72,
                      20,
                      bottomPad + 130,
                    ),
                    child: Hero(
                      tag: 'vb_img_${it.data.thumbnailDataUri.hashCode}_$index',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8A2BE2).withValues(alpha: 0.45),
                              blurRadius: 48,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: bytes != null
                              ? Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : Container(
                                  color: const Color(0xFF1A0830),
                                  child: const Icon(Icons.image_outlined,
                                      color: Color(0xFF6B7280), size: 56),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Close button
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Spacer(),
                      // Page counter
                      if (widget.items.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom bar: title + source + dots
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, bottomPad + 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dots indicator
                      if (widget.items.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.items.length, (i) {
                              final isActive = i == _currentIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isActive ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF8A2BE2),
                                            Color(0xFFCE93D8),
                                          ],
                                        )
                                      : null,
                                  color: isActive
                                      ? null
                                      : Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                      // Title
                      if (item.data.title.isNotEmpty)
                        Text(
                          item.data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      if (item.data.title.isNotEmpty &&
                          item.data.sourceLink.isNotEmpty)
                        const SizedBox(height: 5),
                      // Source domain
                      if (item.data.sourceLink.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF8A2BE2).withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFAB47BC)
                                      .withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_rounded,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    _domainFromUrl(item.data.sourceLink),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 11,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
