import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A persistent WebView that runs through all moodboard search queries in-place.
/// Navigates between queries without popping/re-opening, then returns all
/// extracted images in one shot.
class MoodboardWebView extends StatefulWidget {
  final List<String> queries;
  final String theme;

  const MoodboardWebView({
    required this.queries,
    required this.theme,
    super.key,
  });

  @override
  State<MoodboardWebView> createState() => _MoodboardWebViewState();
}

class _MoodboardWebViewState extends State<MoodboardWebView>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  int _currentQueryIndex = 0;
  bool _isExtracting = false;
  bool _hasPopped = false;
  Timer? _queryTimeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;
  String _statusText = '';

  final List<VisualBrowseImageData> _allExtracted = [];
  final Set<String> _seen = {};
  static const int _maxPerQuery = 3;

  // Pin-by-pin extraction state
  List<String> _pinUrls = [];
  int _pinIndex = 0;
  final List<VisualBrowseImageData> _currentQueryResults = [];

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _statusText = _searchingLabel();
    _startQueryTimeout();

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
    _queryTimeoutTimer?.cancel();
    _gradientController.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String get _currentQuery => widget.queries[_currentQueryIndex];

  String _searchingLabel() {
    if (widget.queries.isEmpty) return 'Searching images...';
    return 'Searching ${_currentQueryIndex + 1}/${widget.queries.length}';
  }

  void _startQueryTimeout() {
    _queryTimeoutTimer?.cancel();
    _queryTimeoutTimer = Timer(const Duration(seconds: 35), () {
      // Treat timeout as empty result for this query, move on
      _advanceToNextQuery([]);
    });
  }

  void _popWithResults() {
    if (_hasPopped) return;
    _hasPopped = true;
    _queryTimeoutTimer?.cancel();
    if (mounted) Navigator.pop(context, _allExtracted);
  }

  /// Called after extracting images for one query.
  /// Adds unique images, then navigates to the next query or pops.
  void _advanceToNextQuery(List<VisualBrowseImageData> extracted) {
    for (final img in extracted.take(_maxPerQuery)) {
      if (img.thumbnailDataUri.isNotEmpty &&
          !_seen.contains(img.thumbnailDataUri)) {
        _seen.add(img.thumbnailDataUri);
        _allExtracted.add(img);
      }
    }

    _currentQueryIndex++;

    if (_currentQueryIndex >= widget.queries.length) {
      _popWithResults();
      return;
    }

    // Navigate to the next query in the same WebView
    _isExtracting = false;
    _pinUrls = [];
    _pinIndex = 0;
    _currentQueryResults.clear();
    _startQueryTimeout();
    if (mounted) {
      setState(() {
        _showCaptchaPrompt = false;
        _progress = 0;
        _statusText = _searchingLabel();
      });
    }

    final encoded = Uri.encodeComponent(_currentQuery);
    _controller?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('https://www.pinterest.com/search/pins/?q=$encoded'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
    );
  }

  // ── extraction logic (pin-by-pin) ─────────────────────────────────────────

  Future<bool> _isCaptchaOrConsentPage() async {
    if (_controller == null) return false;
    final check = await _controller!.evaluateJavascript(source: '''
(function() {
  var url = window.location.href;
  if (url.indexOf('/login') !== -1) return 'captcha';
  if (url.indexOf('/challenge') !== -1) return 'captcha';
  if (document.querySelector('input[name="password"]') !== null) return 'captcha';
  return 'ok';
})();
''');
    final result = (check ?? '').toString();
    return result == 'captcha';
  }

  /// Phase 1: called when a Pinterest search results page loads.
  /// Scrolls to reveal pins, collects their URLs, then navigates to the first one.
  Future<void> _collectPinUrls() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;
    _pinUrls = [];
    _pinIndex = 0;
    _currentQueryResults.clear();

    await Future.delayed(const Duration(milliseconds: 1500));

    if (await _isCaptchaOrConsentPage()) {
      _isExtracting = false;
      if (mounted) setState(() => _showCaptchaPrompt = true);
      _queryTimeoutTimer?.cancel();
      _queryTimeoutTimer = Timer(const Duration(seconds: 60), () {
        _advanceToNextQuery([]);
      });
      return;
    }

    if (mounted) setState(() => _statusText = 'Finding pins...');

    // Scroll to reveal more pin thumbnails
    for (int step = 0; step < 4; step++) {
      await _controller!.evaluateJavascript(source: '''
(function() { window.scrollBy({ top: window.innerHeight * 0.8, behavior: 'smooth' }); })();
''');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final result = await _controller!.evaluateJavascript(source: '''
(function() {
  var links = document.querySelectorAll('a[href*="/pin/"]');
  var urls = [];
  var seen = {};
  for (var i = 0; i < links.length; i++) {
    var href = links[i].href;
    if (href && !seen[href] && href.indexOf('pinterest.com/pin/') !== -1) {
      seen[href] = true;
      urls.push(href);
    }
  }
  return JSON.stringify(urls.slice(0, 12));
})();
''');

    if (result != null && result != 'null') {
      try {
        final List<dynamic> parsed =
            jsonDecode(result is String ? result : result.toString());
        _pinUrls = parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    _isExtracting = false;

    if (_pinUrls.isEmpty) {
      _advanceToNextQuery([]);
      return;
    }

    if (mounted) {
      setState(() => _statusText =
          'Opening pin 1/${_pinUrls.length.clamp(1, _maxPerQuery)}...');
    }
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_pinUrls[0])),
    );
  }

  /// Phase 2: called when an individual pin page loads.
  /// Extracts the highest-quality image, then moves to the next pin or finishes.
  Future<void> _extractFromPinPage() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    // Give the pin page time to render its image
    await Future.delayed(const Duration(milliseconds: 2000));

    if (await _isCaptchaOrConsentPage()) {
      _isExtracting = false;
      if (mounted) setState(() => _showCaptchaPrompt = true);
      _queryTimeoutTimer?.cancel();
      _queryTimeoutTimer = Timer(const Duration(seconds: 60), () {
        _advanceToNextQuery([]);
      });
      return;
    }

    if (mounted) {
      setState(() => _statusText =
          'Extracting image ${_pinIndex + 1}/${_pinUrls.length.clamp(1, _maxPerQuery)}...');
    }

    final result = await _controller!.evaluateJavascript(source: r'''
(function() {
  var imgs = document.querySelectorAll('img[src*="pinimg.com"]');
  var best = null;
  var bestSize = 0;
  for (var i = 0; i < imgs.length; i++) {
    var img = imgs[i];
    var w = img.naturalWidth || img.width || 0;
    var h = img.naturalHeight || img.height || 0;
    var size = w * h;
    if (size > bestSize) { bestSize = size; best = img; }
  }
  if (!best || bestSize < 10000) return 'null';
  var src = best.getAttribute('src') || '';
  // Upgrade to 736x (highest reliably available Pinterest CDN size)
  src = src.replace(/\/\d+x\//, '/736x/');
  var title = (best.alt || '').trim();
  return JSON.stringify({ thumbnailDataUri: src, title: title, sourceLink: window.location.href });
})();
''');

    if (result != null && result != 'null') {
      try {
        final Map<String, dynamic> parsed =
            jsonDecode(result is String ? result : result.toString());
        final img = VisualBrowseImageData(
          thumbnailDataUri: (parsed['thumbnailDataUri'] ?? '').toString(),
          title: (parsed['title'] ?? '').toString(),
          sourceLink: (parsed['sourceLink'] ?? '').toString(),
        );
        if (img.thumbnailDataUri.isNotEmpty) {
          _currentQueryResults.add(img);
        }
      } catch (_) {}
    }

    _pinIndex++;
    _isExtracting = false;

    // Done if we have enough images or exhausted the collected pin URLs
    if (_currentQueryResults.length >= _maxPerQuery ||
        _pinIndex >= _pinUrls.length) {
      _advanceToNextQuery(List.from(_currentQueryResults));
      return;
    }

    if (mounted) {
      setState(() => _statusText =
          'Opening pin ${_pinIndex + 1}/${_pinUrls.length.clamp(1, _maxPerQuery)}...');
    }
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_pinUrls[_pinIndex])),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final initialEncoded = widget.queries.isNotEmpty
        ? Uri.encodeComponent(widget.queries[0])
        : '';
    final initialUrl =
        'https://www.pinterest.com/search/pins/?q=$initialEncoded';

    return Scaffold(
      backgroundColor: const Color(0xFF8A2BE2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8A2BE2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: _popWithResults,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (!_showCaptchaPrompt && widget.queries.isNotEmpty)
              Text(
                _currentQueryIndex < widget.queries.length
                    ? _currentQuery
                    : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                // Animated radial glows
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
                // WebView card
                Center(
                  child: Container(
                    width: screenWidth * 0.80,
                    height: (screenHeight -
                            kToolbarHeight -
                            safeTop -
                            safeBottom) *
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
                              ? _buildWebView(initialUrl)
                              : IgnorePointer(
                                  child: _buildWebView(initialUrl),
                                ),
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
                                  'Pinterest requires verification. Please complete it to continue.',
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
                // Progress pill — how many queries done out of total
                Positioned(
                  bottom: 24 + safeBottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _QueryProgressPill(
                      current: _currentQueryIndex,
                      total: widget.queries.length,
                      extracted: _allExtracted.length,
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

  Widget _buildWebView(String initialUrl) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(initialUrl),
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
        if (mounted) setState(() => _progress = progress / 100);
        if (progress > 30 && progress < 90) {
          if (mounted) setState(() => _statusText = 'Loading images...');
        }
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        if (_showCaptchaPrompt) {
          if ((currentUrl.contains('pinterest.com/search/') ||
                  currentUrl.contains('pinterest.com/pin/')) &&
              !(await _isCaptchaOrConsentPage())) {
            if (mounted) setState(() => _showCaptchaPrompt = false);
            _isExtracting = false;
            if (_pinUrls.isNotEmpty && _pinIndex < _pinUrls.length) {
              await _extractFromPinPage();
            } else {
              await _collectPinUrls();
            }
          }
          return;
        }
        if (currentUrl.contains('pinterest.com/search/')) {
          if (mounted) setState(() => _statusText = _searchingLabel());
          await _collectPinUrls();
        } else if (currentUrl.contains('pinterest.com/pin/')) {
          await _extractFromPinPage();
        }
      },
      onReceivedError: (controller, request, error) {
        print('MoodboardWebView: load error: ${error.description}');
        _advanceToNextQuery([]);
      },
    );
  }
}

// ── Progress pill shown at the bottom while browsing ─────────────────────────

class _QueryProgressPill extends StatelessWidget {
  final int current;
  final int total;
  final int extracted;

  const _QueryProgressPill({
    required this.current,
    required this.total,
    required this.extracted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: total > 0 ? current / total : null,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$current/$total queries  •  $extracted images',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
