import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VisualBrowseWebView extends StatefulWidget {
  final String query;

  const VisualBrowseWebView({required this.query, super.key});

  @override
  State<VisualBrowseWebView> createState() => _VisualBrowseWebViewState();
}

class _VisualBrowseWebViewState extends State<VisualBrowseWebView>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _isExtracting = false;
  bool _hasPopped = false;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;
  String _statusText = 'Searching images...';
  int _imageCount = 0;

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _popWithResults([]);
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

  void _popWithResults(List<VisualBrowseImageData> results) {
    if (_hasPopped) return;
    _hasPopped = true;
    _timeoutTimer?.cancel();
    Navigator.pop(context, results);
  }

  Future<bool> _isCaptchaOrConsentPage() async {
    if (_controller == null) return false;
    final check = await _controller!.evaluateJavascript(source: '''
(function() {
  var body = document.body ? document.body.innerText : '';
  if (document.querySelector('#captcha-form') !== null) return 'captcha';
  if (document.querySelector('form[action*="sorry"]') !== null) return 'captcha';
  if (body.indexOf('unusual traffic') !== -1) return 'captcha';
  if (body.indexOf('not a robot') !== -1) return 'captcha';
  if (document.querySelector('form[action*="consent"]') !== null) return 'consent';
  return 'ok';
})();
''');
    final result = (check ?? '').toString();
    return result == 'captcha' || result == 'consent';
  }

  Future<void> _scrollToLoadImages() async {
    if (_controller == null) return;
    _updateStatus('Loading images...');

    for (int step = 0; step < 8; step++) {
      await _controller!.evaluateJavascript(source: '''
(function() {
  window.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' });
})();
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
      if (count >= 10) {
        setState(() => _imageCount = count);
        break;
      }
      if (count > 0) {
        setState(() => _imageCount = count);
        _updateStatus('Found $count images...');
      }
    }
  }

  Future<List<VisualBrowseImageData>> _extractImagesFromPage() async {
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
    // Fallback: find any nearby <a>
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
    // Walk up to find nearby text
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

  // Strategy 1: data URI thumbnails (most reliable for Google Images udm=2)
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

  // Strategy 2: https:// thumbnail URLs if data URIs not found
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
          return VisualBrowseImageData(
            thumbnailDataUri: (e['thumbnailDataUri'] ?? '').toString(),
            title: (e['title'] ?? '').toString(),
            sourceLink: (e['sourceLink'] ?? '').toString(),
          );
        }).where((d) => d.thumbnailDataUri.isNotEmpty).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> _extractResults() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    if (await _isCaptchaOrConsentPage()) {
      _isExtracting = false;
      setState(() => _showCaptchaPrompt = true);
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        _popWithResults([]);
      });
      return;
    }

    try {
      _updateStatus('Reading image results...');
      var results = await _extractImagesFromPage();

      if (results.length < 8) {
        await _scrollToLoadImages();
        await Future.delayed(const Duration(milliseconds: 500));
        _updateStatus('Extracting images...');
        final moreResults = await _extractImagesFromPage();

        final seen = <String>{};
        final merged = <VisualBrowseImageData>[];
        for (final r in [...results, ...moreResults]) {
          if (!seen.contains(r.thumbnailDataUri)) {
            seen.add(r.thumbnailDataUri);
            merged.add(r);
          }
        }
        results = merged;
      }

      if (results.length > 10) results = results.sublist(0, 10);

      setState(() => _imageCount = results.length);
      _updateStatus('Found ${results.length} images');

      await Future.delayed(const Duration(milliseconds: 300));
      _popWithResults(results);
    } catch (e) {
      print('VisualBrowseWebView: Error extracting images: $e');
      _popWithResults([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encodedQuery = Uri.encodeComponent(widget.query);
    final searchUrl =
        'https://www.google.com/search?q=$encodedQuery&udm=2';
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
          onPressed: () => _popWithResults([]),
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
            if (_imageCount > 0 && !_showCaptchaPrompt)
              Text(
                '$_imageCount images found',
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
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
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
                      center: Alignment(
                        0.6 * sin(t * 0.7),
                        0.6 * cos(t * 0.7),
                      ),
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
                      center: Alignment(
                        -0.5 * cos(t * 0.5),
                        0.5 * sin(t * 0.5),
                      ),
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
                              : IgnorePointer(
                                  child: _buildWebView(searchUrl)),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: const Text(
                                  'Google requires verification. Please complete it to continue.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
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
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
        setState(() {
          _progress = progress / 100;
        });
        if (progress > 30 && progress < 90) {
          _updateStatus('Loading image results...');
        }
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        if (_showCaptchaPrompt) {
          if (currentUrl.contains('/search?') &&
              !(await _isCaptchaOrConsentPage())) {
            setState(() => _showCaptchaPrompt = false);
            _isExtracting = false;
            await _extractResults();
          }
          return;
        }
        _updateStatus('Page loaded, scanning images...');
        await _extractResults();
      },
      onReceivedError: (controller, request, error) {
        print('VisualBrowseWebView: Load error: ${error.description}');
        _popWithResults([]);
      },
    );
  }
}
