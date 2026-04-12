import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/short_video.dart';
import 'package:bavi/models/thread.dart';
import 'package:bavi/home/widgets/search_extraction_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Phase of the two-stage webview extraction.
enum _WebViewPhase { webSearch, imageSearch, done }

class GoogleSearchWebView extends StatefulWidget {
  final String query;
  final bool quickMode;

  const GoogleSearchWebView({required this.query, this.quickMode = false, super.key});

  @override
  State<GoogleSearchWebView> createState() => _GoogleSearchWebViewState();
}

class _GoogleSearchWebViewState extends State<GoogleSearchWebView>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _isExtracting = false;
  bool _hasPopped = false;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;
  String _statusText = 'Searching...';
  int _resultCount = 0;

  _WebViewPhase _phase = _WebViewPhase.webSearch;
  List<ExtractedResultInfo> _webResults = [];

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      _popWithResults(BrowseSearchResult(webResults: _webResults, images: []));
    });

    _gradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _gradientAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _gradientController.dispose();
    super.dispose();
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _statusText = status;
      });
    }
  }

  void _popWithResults(BrowseSearchResult result) {
    if (_hasPopped) return;
    _hasPopped = true;
    _timeoutTimer?.cancel();
    Navigator.pop(context, result);
  }

  /// Detect if the current page is a CAPTCHA/consent page rather than results.
  Future<bool> _isCaptchaOrConsentPage() async {
    if (_controller == null) return false;
    return SearchExtractionHelper.isCaptchaOrConsentPage(_controller!);
  }

  Future<List<ExtractedResultInfo>> _extractResultsFromPage() async {
    if (_controller == null) return [];
    return SearchExtractionHelper.extractResultsFromPage(_controller!);
  }

  Future<List<VisualBrowseResultData>> _extractImagesFromPage() async {
    if (_controller == null) return [];

    final result = await _controller!.evaluateJavascript(source: r'''
(function() {
  var results = [];
  var seen = {};

  function getSourceLink(imgEl) {
    var node = imgEl.parentElement;
    for (var i = 0; i < 12 && node; i++) {
      if (node.tagName === 'A' && node.href) {
        var h = node.href;
        if (h && h.indexOf('google') === -1 && h.indexOf('javascript') === -1) return h;
      }
      node = node.parentElement;
    }
    var node2 = imgEl.parentElement;
    for (var j = 0; j < 5 && node2; j++) {
      var a = node2.querySelector('a[href]');
      if (a && a.href && a.href.indexOf('google') === -1) return a.href;
      node2 = node2.parentElement;
    }
    return '';
  }

  function getNearbyTitle(imgEl) {
    var t = (imgEl.alt || imgEl.getAttribute('aria-label') || '').trim();
    if (t.length > 3) return t;
    var node = imgEl.parentElement;
    for (var i = 0; i < 6 && node; i++) {
      var candidates = node.querySelectorAll('div[role="heading"], span, div');
      for (var c = 0; c < candidates.length; c++) {
        var txt = (candidates[c].innerText || '').trim();
        if (txt.length > 5 && txt.length < 150 && txt.indexOf('\n') === -1) return txt;
      }
      node = node.parentElement;
    }
    return '';
  }

  var allImgs = document.querySelectorAll('img');
  for (var i = 0; i < allImgs.length && results.length < 10; i++) {
    var img = allImgs[i];
    var src = img.getAttribute('src') || '';
    if (!src || src.length < 100) continue;
    if (seen[src]) continue;

    var w = img.naturalWidth || img.width || 0;
    var h = img.naturalHeight || img.height || 0;
    if (w < 80 || h < 80) continue;

    seen[src] = true;
    var title = getNearbyTitle(img);
    var link = getSourceLink(img);
    results.push({ thumbnailDataUri: src, title: title, sourceLink: link });
  }

  if (results.length < 5) {
    for (var j = 0; j < allImgs.length && results.length < 10; j++) {
      var img2 = allImgs[j];
      var src2 = img2.getAttribute('src') || img2.getAttribute('data-src') || '';
      if (!src2 || src2.indexOf('http') !== 0) continue;
      if (seen[src2]) continue;
      if (src2.indexOf('google') !== -1 || src2.indexOf('gstatic') !== -1) continue;

      var w2 = img2.naturalWidth || img2.width || 0;
      var h2 = img2.naturalHeight || img2.height || 0;
      if (w2 < 80 || h2 < 80) continue;

      seen[src2] = true;
      results.push({
        thumbnailDataUri: src2,
        title: getNearbyTitle(img2),
        sourceLink: getSourceLink(img2)
      });
    }
  }

  return JSON.stringify(results.slice(0, 10));
})();
''');

    if (result != null && result != 'null') {
      final String jsonStr = result is String ? result : result.toString();
      try {
        final List<dynamic> parsed = jsonDecode(jsonStr);
        return parsed.map((e) {
          return VisualBrowseResultData(
            thumbnailDataUri: (e['thumbnailDataUri'] ?? '').toString(),
            title: (e['title'] ?? '').toString(),
            sourceLink: (e['sourceLink'] ?? '').toString(),
          );
        }).where((d) => d.thumbnailDataUri.isNotEmpty).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> _scrollToLoadImages() async {
    if (_controller == null) return;
    for (int step = 0; step < 6; step++) {
      await _controller!.evaluateJavascript(source: '''
(function() { window.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' }); })();
''');
      await Future.delayed(const Duration(milliseconds: 600));
      final countResult = await _controller!.evaluateJavascript(source: '''
(function() {
  var imgs = document.querySelectorAll('img');
  var count = 0;
  for (var i = 0; i < imgs.length; i++) {
    var src = imgs[i].getAttribute('src') || '';
    var w = imgs[i].naturalWidth || imgs[i].width || 0;
    var h = imgs[i].naturalHeight || imgs[i].height || 0;
    if (src.length > 100 && w >= 80 && h >= 80) count++;
  }
  return count;
})();
''');
      final count = int.tryParse(countResult?.toString() ?? '0') ?? 0;
      if (count >= 8) break;
    }
  }

  Future<void> _scrollToLastOrganicResult() async {
    if (_controller == null) return;
    _updateStatus('Scanning results...');
    await SearchExtractionHelper.scrollToLastOrganicResult(
      _controller!,
      onStatus: (s) {
        _updateStatus(s);
        final count = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (count > 0) setState(() { _resultCount = count; });
      },
    );
  }

  /// Phase 1: extract web results, then navigate to Images tab.
  Future<void> _extractWebResults() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    if (await _isCaptchaOrConsentPage()) {
      _isExtracting = false;
      setState(() { _showCaptchaPrompt = true; });
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        _popWithResults(BrowseSearchResult(webResults: [], images: []));
      });
      return;
    }

    try {
      if (widget.quickMode) {
        _updateStatus('Extracting...');
        List<ExtractedResultInfo> results = [];
        for (int attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(const Duration(milliseconds: 500));
          results = await _extractResultsFromPage();
          if (results.isNotEmpty) break;
        }
        setState(() { _resultCount = results.length; });
        _webResults = results.length > 15 ? results.sublist(0, 15) : results;
      } else {
        _updateStatus('Reading page...');
        var allResults = await _extractResultsFromPage();
        _updateStatus('Found ${allResults.length} results');
        if (allResults.length < 8) {
          await _scrollToLastOrganicResult();
        }
        await Future.delayed(const Duration(milliseconds: 500));
        _updateStatus('Extracting results...');
        final moreResults = await _extractResultsFromPage();
        final mergedResults = <ExtractedResultInfo>[];
        final localSeen = <String>{};
        for (final r in [...allResults, ...moreResults]) {
          if (!localSeen.contains(r.url)) {
            localSeen.add(r.url);
            mergedResults.add(r);
          }
        }
        allResults = mergedResults;
        if (allResults.length > 15) allResults = allResults.sublist(0, 15);
        setState(() { _resultCount = allResults.length; });
        _webResults = allResults;
      }
    } catch (e) {
      print('GoogleSearchWebView: Error extracting web results: $e');
      _webResults = [];
    }

    // Phase 2: navigate to Google Images
    _isExtracting = false;
    _phase = _WebViewPhase.imageSearch;
    _updateStatus('Finding images...');
    setState(() { _progress = 0; });

    final encodedQuery = Uri.encodeComponent(widget.query);
    final imagesUrl = 'https://www.google.com/search?q=$encodedQuery&udm=2';
    try {
      await _controller!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(imagesUrl),
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ),
      );
    } catch (e) {
      print('GoogleSearchWebView: Failed to navigate to images: $e');
      _popWithResults(BrowseSearchResult(webResults: _webResults, images: []));
    }
  }

  /// Phase 2: extract images from Google Images page.
  Future<void> _extractImages() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    if (await _isCaptchaOrConsentPage()) {
      // Skip images silently rather than showing a CAPTCHA prompt again
      _popWithResults(BrowseSearchResult(webResults: _webResults, images: []));
      return;
    }

    try {
      _updateStatus('Extracting images...');
      var images = await _extractImagesFromPage();
      if (images.length < 6) {
        await _scrollToLoadImages();
        await Future.delayed(const Duration(milliseconds: 500));
        final moreImages = await _extractImagesFromPage();
        final seen = <String>{};
        final merged = <VisualBrowseResultData>[];
        for (final img in [...images, ...moreImages]) {
          if (!seen.contains(img.thumbnailDataUri)) {
            seen.add(img.thumbnailDataUri);
            merged.add(img);
          }
        }
        images = merged;
      }
      if (images.length > 10) images = images.sublist(0, 10);
      _updateStatus('Found ${images.length} images');
      await Future.delayed(const Duration(milliseconds: 300));
      _popWithResults(BrowseSearchResult(webResults: _webResults, images: images));
    } catch (e) {
      print('GoogleSearchWebView: Error extracting images: $e');
      _popWithResults(BrowseSearchResult(webResults: _webResults, images: []));
    }
  }

  @override
  Widget build(BuildContext context) {
    final encodedQuery = Uri.encodeComponent(widget.query);
    final searchUrl = 'https://www.google.com/search?q=$encodedQuery&num=15';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF8A2BE2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8A2BE2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => _popWithResults(
            BrowseSearchResult(webResults: _webResults, images: []),
          ),
        ),
        title: Column(
          children: [
            Text(
              _showCaptchaPrompt ? 'Please verify below' : _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            if (_resultCount > 0 && !_showCaptchaPrompt && _phase == _WebViewPhase.webSearch)
              Text(
                '$_resultCount sources found',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: true,
        bottom: _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          final t = _gradientAnimation.value;
          final beginX = cos(t);
          final beginY = sin(t);
          final endX = cos(t + pi);
          final endY = sin(t + pi);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(beginX, beginY),
                end: Alignment(endX, endY),
                colors: const [
                  Color(0xFF6A1B9A),
                  Color(0xFF8A2BE2),
                  Color(0xFFAB47BC),
                  Color(0xFF7B1FA2),
                  Color(0xFF8A2BE2),
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.6 * sin(t * 0.7), 0.6 * cos(t * 0.7)),
                      radius: 1.0,
                      colors: [
                        const Color(0xFFCE93D8).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.5 * cos(t * 0.5), 0.5 * sin(t * 0.5)),
                      radius: 0.8,
                      colors: [
                        const Color(0xFF4A148C).withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: screenWidth * 0.80,
                    height: (screenHeight -
                            kToolbarHeight -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom) *
                        0.80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          _showCaptchaPrompt
                              ? _buildWebView(searchUrl)
                              : IgnorePointer(child: _buildWebView(searchUrl)),
                          if (_showCaptchaPrompt)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(24),
                                    bottomRight: Radius.circular(24),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: const Text(
                                  'Google requires verification. Please complete it to continue.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebView(String searchUrl) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(searchUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: '',
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: true,
        clearCache: false,
        thirdPartyCookiesEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      onProgressChanged: (controller, progress) {
        setState(() { _progress = progress / 100; });
        if (progress > 30 && progress < 90) {
          _updateStatus(_phase == _WebViewPhase.imageSearch ? 'Loading images...' : 'Loading page...');
        }
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        if (_showCaptchaPrompt) {
          if (currentUrl.contains('/search?') && !(await _isCaptchaOrConsentPage())) {
            setState(() { _showCaptchaPrompt = false; });
            _isExtracting = false;
            // Resume from correct phase
            if (_phase == _WebViewPhase.imageSearch) {
              await _extractImages();
            } else {
              await _extractWebResults();
            }
          }
          return;
        }
        if (_phase == _WebViewPhase.webSearch) {
          _updateStatus('Page loaded, extracting...');
          await _extractWebResults();
        } else if (_phase == _WebViewPhase.imageSearch) {
          await _extractImages();
        }
      },
      onReceivedError: (controller, request, error) {
        print('GoogleSearchWebView: Load error: ${error.description}');
        _popWithResults(BrowseSearchResult(webResults: _webResults, images: []));
      },
    );
  }
}
