import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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

  void _popWithResults(List<ExtractedResultInfo> results) {
    if (_hasPopped) return;
    _hasPopped = true;
    _timeoutTimer?.cancel();
    Navigator.pop(context, results);
  }

  /// Detect if the current page is a CAPTCHA/consent page rather than results.
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

  Future<List<ExtractedResultInfo>> _extractResultsFromPage() async {
    if (_controller == null) return [];

    final result = await _controller!.evaluateJavascript(source: '''
(function() {
  var results = [];
  var seen = {};

  function isGoogleInternal(url) {
    if (!url) return true;
    try {
      var host = new URL(url).hostname;
      if (host.indexOf('google') !== -1) return true;
      if (host.indexOf('gstatic') !== -1) return true;
      if (host.indexOf('googleapis') !== -1) return true;
      if (host.indexOf('schema.org') !== -1) return true;
    } catch(e) { return true; }
    if (url.indexOf('javascript:') === 0) return true;
    if (url === '#' || url.charAt(0) === '#') return true;
    return false;
  }

  function isYouTubeVideo(url) {
    if (!url) return false;
    try {
      var u = new URL(url);
      var h = u.hostname;
      if (h === 'youtu.be') return true;
      if (h.indexOf('youtube.') !== -1) {
        var p = u.pathname;
        if (p.indexOf('/watch') === 0 || p.indexOf('/shorts') === 0 || p.indexOf('/video') === 0) return true;
      }
    } catch(e) {}
    return false;
  }

  function cleanUrl(url) {
    if (!url) return '';
    if (url.indexOf('/url?') !== -1 || url.indexOf('google.com/url') !== -1) {
      try {
        var u = new URL(url);
        var q = u.searchParams.get('q') || u.searchParams.get('url');
        if (q && q.indexOf('http') === 0) return q;
      } catch(e) {}
    }
    return url;
  }

  // Convert Google breadcrumb text (e.g. "en.wikipedia.org › wiki › Love") to URL
  function breadcrumbToUrl(text) {
    if (!text) return '';
    text = text.trim();
    if (text.indexOf('http') === 0) return text;
    if (text.indexOf('//') === 0) return 'https:' + text;
    // Replace breadcrumb separators with slashes, remove spaces
    text = text.replace(/\\s*[\\u203a>»·|]\\s*/g, '/').replace(/\\/\\//g, '/');
    // Only treat as URL if it looks like a domain (has dot, no spaces)
    if (text.length > 4 && text.indexOf('.') !== -1 && text.indexOf(' ') === -1) {
      return 'https://' + text;
    }
    return '';
  }

  // Walk up DOM tree to find the displayed URL text in cite or span
  function getBreadcrumbUrl(startEl) {
    var node = startEl;
    for (var i = 0; i < 10 && node; i++) {
      var candidates = ['cite.tLk3Jb', 'span.nC62wb', '[data-snf="X87mVe"] span', '.ob9lvb', '.VndCse'];
      for (var s = 0; s < candidates.length; s++) {
        var el = node.querySelector ? node.querySelector(candidates[s]) : null;
        if (el) {
          var u = breadcrumbToUrl((el.innerText || el.textContent || '').trim());
          if (u && !isGoogleInternal(u)) return u;
        }
      }
      node = node.parentElement;
    }
    return '';
  }

  function getSnippet(startEl) {
    var block = startEl;
    for (var i = 0; i < 10 && block; i++) {
      if (!block.parentElement) break;
      block = block.parentElement;
      var cl = block.classList;
      if (cl && (cl.contains('g') || cl.contains('MjjYud') || cl.contains('hlcw0c'))) break;
      if (block.getAttribute('data-hveid') !== null) break;
    }
    if (!block) return '';
    var selectors = ['.VwiC3b', '[data-snf="nke7rc"]', '[data-sncf]', '.IsZvec',
                     '.lEBKkf', '.ITZIwc', '.GI74Re', '.yDYNvb', '.st', '.s'];
    for (var s = 0; s < selectors.length; s++) {
      try {
        var el = block.querySelector(selectors[s]);
        if (el && el.innerText && el.innerText.trim().length > 15)
          return el.innerText.trim().substring(0, 400);
      } catch(e) {}
    }
    return '';
  }

  // Strategy 1: New Google layout (2025+) — titles in div.F0FGWb[role="heading"],
  // URLs only available as breadcrumb text in span.nC62wb or cite.tLk3Jb
  var cardHeadings = document.querySelectorAll('.F0FGWb[role="heading"], [data-snf="GuLy6c"] [role="heading"]');
  for (var i = 0; i < cardHeadings.length && results.length < 15; i++) {
    var heading = cardHeadings[i];
    var title = (heading.innerText || '').trim();
    if (!title || title.length < 3 || title.length > 250) continue;

    var url = getBreadcrumbUrl(heading);
    if (!url) {
      // Fallback: try anchor href (works when old /url?q= format is still used)
      var anc = heading.closest('a');
      if (!anc) { var pp = heading.parentElement; for (var dd = 0; dd < 5 && pp; dd++) { anc = pp.querySelector('a[href]'); if (anc) break; pp = pp.parentElement; } }
      if (anc) { var hf = cleanUrl(anc.href || ''); if (hf && !isGoogleInternal(hf)) url = hf; }
    }

    if (!url || isGoogleInternal(url) || isYouTubeVideo(url) || seen[url]) continue;
    seen[url] = true;
    results.push({ url: url, title: title, excerpts: getSnippet(heading) });
  }

  // Strategy 2: h3-based (old layout + PAA expanded answers)
  if (results.length < 8) {
    var allH3 = document.querySelectorAll('h3');
    for (var j = 0; j < allH3.length && results.length < 15; j++) {
      var h3 = allH3[j];
      var titleH3 = (h3.innerText || '').trim();
      if (!titleH3 || titleH3.length < 2 || titleH3.length > 250) continue;

      var a = h3.closest('a');
      if (!a) { var ph = h3.parentElement; for (var dh = 0; dh < 4 && ph; dh++) { a = ph.querySelector('a[href]'); if (!a) a = ph.closest('a'); ph = ph && ph.parentElement; } }

      var urlH3 = a ? cleanUrl(a.href || '') : '';
      // If /goto?url= or other google-internal, try breadcrumb fallback
      if (!urlH3 || isGoogleInternal(urlH3)) urlH3 = getBreadcrumbUrl(h3);
      if (!urlH3 || isGoogleInternal(urlH3)) { var dc = h3.closest('[data-url]'); if (dc) urlH3 = dc.getAttribute('data-url') || ''; }

      if (!urlH3 || isGoogleInternal(urlH3) || isYouTubeVideo(urlH3) || seen[urlH3]) continue;
      seen[urlH3] = true;
      results.push({ url: urlH3, title: titleH3, excerpts: getSnippet(h3) });
    }
  }

  // Strategy 3: data-hveid blocks
  if (results.length < 8) {
    var hvBlocks = document.querySelectorAll('[data-hveid]');
    for (var b = 0; b < hvBlocks.length && results.length < 15; b++) {
      var blk = hvBlocks[b];
      var lnk = blk.querySelector('a[href]');
      if (!lnk) continue;
      var hrefB = cleanUrl(lnk.href || '');
      if (!hrefB || isGoogleInternal(hrefB)) hrefB = getBreadcrumbUrl(blk);
      if (!hrefB || isGoogleInternal(hrefB) || isYouTubeVideo(hrefB) || seen[hrefB]) continue;
      var hEl = blk.querySelector('.F0FGWb[role="heading"]') || blk.querySelector('h3') || blk.querySelector('[role="heading"]');
      var titleB = hEl ? (hEl.innerText || '').trim() : (lnk.innerText || '').trim();
      if (!titleB || titleB.length < 3 || titleB.length > 200) continue;
      seen[hrefB] = true;
      results.push({ url: hrefB, title: titleB, excerpts: getSnippet(hEl || lnk) });
    }
  }

  // Strategy 4: all external links fallback
  if (results.length < 5) {
    var allLinks = document.querySelectorAll('a[href]');
    for (var k = 0; k < allLinks.length && results.length < 15; k++) {
      var lk = allLinks[k];
      var lHref = cleanUrl(lk.href || '');
      if (!lHref || isGoogleInternal(lHref) || isYouTubeVideo(lHref) || seen[lHref]) continue;
      var lText = (lk.innerText || '').trim();
      if (lText.length < 8 || lText.length > 200) continue;
      seen[lHref] = true;
      results.push({ url: lHref, title: lText, excerpts: getSnippet(lk) });
    }
  }

  return JSON.stringify(results.slice(0, 15));
})();
''');

    if (result != null && result != 'null') {
      final String jsonStr = result is String ? result : result.toString();
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((e) {
        return ExtractedResultInfo(
          url: (e['url'] ?? '').toString(),
          title: (e['title'] ?? '').toString(),
          excerpts: (e['excerpts'] ?? '').toString(),
          thumbnailUrl: '',
        );
      }).toList();
    }
    return [];
  }

  Future<void> _scrollToLastOrganicResult() async {
    if (_controller == null) return;

    _updateStatus('Scanning results...');

    int lastKnownCount = 0;
    int stableRounds = 0;

    for (int step = 0; step < 12; step++) {
      final countResult = await _controller!.evaluateJavascript(source: '''
(function() {
  var items = document.querySelectorAll('#rso .g h3, #search .g h3, .F0FGWb[role="heading"], [data-snf="GuLy6c"]');
  return items.length;
})();
''');
      final currentCount =
          int.tryParse(countResult?.toString() ?? '0') ?? 0;

      if (currentCount > 0) {
        _updateStatus('Found $currentCount results');
        setState(() {
          _resultCount = currentCount;
        });
      }

      if (currentCount == lastKnownCount && currentCount > 0) {
        stableRounds++;
        if (stableRounds >= 2) break;
      } else {
        stableRounds = 0;
      }
      lastKnownCount = currentCount;

      await _controller!.evaluateJavascript(source: '''
(function() {
  var items = document.querySelectorAll('#rso .g h3, .F0FGWb[role="heading"], [data-snf="GuLy6c"]');
  if (items.length > 0) {
    items[items.length - 1].scrollIntoView({ behavior: 'smooth', block: 'center' });
  } else {
    window.scrollBy({ top: window.innerHeight * 0.7, behavior: 'smooth' });
  }
})();
''');
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _extractResults() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    await Future.delayed(
        Duration(milliseconds: 1500 + Random().nextInt(1000)));

    // Check if we landed on a CAPTCHA page
    if (await _isCaptchaOrConsentPage()) {
      print('GoogleSearchWebView: CAPTCHA detected, letting user solve it');
      _isExtracting = false;
      setState(() {
        _showCaptchaPrompt = true;
      });
      // Extend timeout to give user time to solve CAPTCHA
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        _popWithResults([]);
      });
      return;
    }

    try {
      if (widget.quickMode) {
        // Quick mode: grab results as soon as any appear
        _updateStatus('Extracting...');
        List<ExtractedResultInfo> results = [];
        for (int attempt = 0; attempt < 5; attempt++) {
          await Future.delayed(const Duration(milliseconds: 500));
          results = await _extractResultsFromPage();
          if (results.isNotEmpty) break;
        }
        setState(() {
          _resultCount = results.length;
        });
        print('GoogleSearchWebView: Extracted ${results.length} results');
        _popWithResults(
            results.length > 15 ? results.sublist(0, 15) : results);
      } else {
        // General mode: same approach as deep drissy for a single query
        _updateStatus('Reading page...');
        var allResults = await _extractResultsFromPage();
        _updateStatus('Found ${allResults.length} results');

        await _scrollToLastOrganicResult();

        await Future.delayed(const Duration(milliseconds: 500));
        _updateStatus('Extracting results...');

        final moreResults = await _extractResultsFromPage();

        // Merge results, dedup by URL
        final mergedResults = <ExtractedResultInfo>[];
        final localSeen = <String>{};
        for (final r in [...allResults, ...moreResults]) {
          if (!localSeen.contains(r.url)) {
            localSeen.add(r.url);
            mergedResults.add(r);
          }
        }
        allResults = mergedResults;

        if (allResults.length > 15) {
          allResults = allResults.sublist(0, 15);
        }

        setState(() {
          _resultCount = allResults.length;
        });
        print('GoogleSearchWebView: Extracted ${allResults.length} results');
        _popWithResults(allResults);
      }
    } catch (e) {
      print('GoogleSearchWebView: Error extracting results: $e');
      _popWithResults([]);
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
          onPressed: () => _popWithResults([]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
            tooltip: 'Copy page HTML (debug)',
            onPressed: () async {
              if (_controller == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final diag = await _controller!.evaluateJavascript(source: '''
(function() {
  var rso = document.querySelector('#rso') || document.querySelector('#search') || document.body;
  var raw = rso ? rso.innerHTML : '';
  return raw.substring(120000);
})()
''');
              if (diag != null) {
                await Clipboard.setData(
                    ClipboardData(text: diag.toString()));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('HTML chunk 2 copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
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
            if (_resultCount > 0 && !_showCaptchaPrompt)
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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white),
                ),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, child) {
          final t = _gradientAnimation.value;
          // Flowing gradient alignment that moves over time
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
                  Color(0xFF6A1B9A), // deep purple
                  Color(0xFF8A2BE2), // main purple
                  Color(0xFFAB47BC), // lighter purple
                  Color(0xFF7B1FA2), // medium purple
                  Color(0xFF8A2BE2), // main purple
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Secondary glow layer for depth
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
                // Subtle second glow moving opposite
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
                // Centered webview at 80% size
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
        // Use the native WebView user agent — matches the TLS fingerprint
        // so Google won't flag a UA/TLS mismatch.
        userAgent: '',
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        // Persist cookies & data across sessions so Google sees a returning visitor
        cacheEnabled: true,
        clearCache: false,
        thirdPartyCookiesEnabled: true,
        // Disable media autoplay to reduce resource usage
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
          _updateStatus('Loading page...');
        }
      },
      onLoadStop: (controller, url) async {
        // If user solved the CAPTCHA and we navigated to a results page, extract
        final currentUrl = url?.toString() ?? '';
        if (_showCaptchaPrompt) {
          // Check if we're past the CAPTCHA now
          if (currentUrl.contains('/search?') &&
              !(await _isCaptchaOrConsentPage())) {
            setState(() {
              _showCaptchaPrompt = false;
            });
            _isExtracting = false;
            await _extractResults();
          }
          return;
        }
        _updateStatus('Page loaded, extracting...');
        await _extractResults();
      },
      onReceivedError: (controller, request, error) {
        print('GoogleSearchWebView: Load error: ${error.description}');
        _popWithResults([]);
      },
    );
  }
}
