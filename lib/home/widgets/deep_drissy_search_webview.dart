import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class DeepDrissySearchWebView extends StatefulWidget {
  final List<String> queries;

  const DeepDrissySearchWebView({required this.queries, super.key});

  @override
  State<DeepDrissySearchWebView> createState() =>
      _DeepDrissySearchWebViewState();
}

class _DeepDrissySearchWebViewState extends State<DeepDrissySearchWebView>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _isExtracting = false;
  bool _hasPopped = false;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;
  String _statusText = 'Searching...';
  int _resultCount = 0;

  int _currentQueryIndex = 0;
  final List<ExtractedResultInfo> _allResults = [];
  final Set<String> _seenUrls = {};

  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    // Longer timeout for multiple queries
    _timeoutTimer = Timer(
        Duration(seconds: 30 + (widget.queries.length * 15)), () {
      _popWithResults(_allResults);
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

  Future<bool> _isCaptchaOrConsentPage() async {
    if (_controller == null) return false;
    final check = await _controller!.evaluateJavascript(source: '''
(function() {
  var hostname = window.location.hostname;
  if (hostname === 'consent.google.com' || hostname.indexOf('consent.google') !== -1) return 'consent';
  var body = document.body ? document.body.innerText : '';
  if (document.querySelector('#captcha-form') !== null) return 'captcha';
  if (document.querySelector('form[action*="sorry"]') !== null) return 'captcha';
  if (body.indexOf('unusual traffic') !== -1) return 'captcha';
  if (body.indexOf('not a robot') !== -1) return 'captcha';
  if (document.querySelector('form[action*="consent"]') !== null) return 'consent';
  if (document.title.indexOf('Before you continue') !== -1) return 'consent';
  return 'ok';
})();
''');
    final result = (check ?? '').toString();
    return result == 'captcha' || result == 'consent';
  }

  Future<void> _scrollToLastOrganicResult() async {
    if (_controller == null) return;

    _updateStatus(
        'Scanning results... (${_currentQueryIndex + 1}/${widget.queries.length})');

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
        _updateStatus(
            'Found $currentCount results (${_currentQueryIndex + 1}/${widget.queries.length})');
        setState(() {
          _resultCount = _allResults.length + currentCount;
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

  function breadcrumbToUrl(text) {
    if (!text) return '';
    text = text.trim();
    if (text.indexOf('http') === 0) return text;
    if (text.indexOf('//') === 0) return 'https:' + text;
    text = text.replace(/\\s*[\\u203a>»·|]\\s*/g, '/').replace(/\\/\\//g, '/');
    if (text.length > 4 && text.indexOf('.') !== -1 && text.indexOf(' ') === -1) {
      return 'https://' + text;
    }
    return '';
  }

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

  Future<void> _extractResults() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    await Future.delayed(
        Duration(milliseconds: 1500 + Random().nextInt(1000)));

    if (await _isCaptchaOrConsentPage()) {
      print(
          'DeepDrissySearchWebView: CAPTCHA detected, letting user solve it');
      _isExtracting = false;
      setState(() {
        _showCaptchaPrompt = true;
      });
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        _popWithResults(_allResults);
      });
      return;
    }

    try {
      _updateStatus(
          'Reading page... (${_currentQueryIndex + 1}/${widget.queries.length})');

      var allResults = await _extractResultsFromPage();
      _updateStatus(
          'Found ${allResults.length} results (${_currentQueryIndex + 1}/${widget.queries.length})');

      await _scrollToLastOrganicResult();

      await Future.delayed(const Duration(milliseconds: 500));
      _updateStatus(
          'Extracting results... (${_currentQueryIndex + 1}/${widget.queries.length})');

      final moreResults = await _extractResultsFromPage();

      // Merge results from this page, dedup by URL
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

      // Add to global results, dedup across queries, tag with source query
      final currentQuery = widget.queries[_currentQueryIndex];
      for (final r in allResults) {
        if (!_seenUrls.contains(r.url)) {
          _seenUrls.add(r.url);
          _allResults.add(ExtractedResultInfo(
            url: r.url,
            title: r.title,
            excerpts: r.excerpts,
            thumbnailUrl: r.thumbnailUrl,
            isVerified: r.isVerified,
            sourceQuery: currentQuery,
          ));
        }
      }

      setState(() {
        _resultCount = _allResults.length;
      });

      print(
          'DeepDrissySearchWebView: Query ${_currentQueryIndex + 1}/${widget.queries.length} extracted ${allResults.length} results, total: ${_allResults.length}');

      // Move to next query or finish
      _currentQueryIndex++;
      if (_currentQueryIndex < widget.queries.length) {
        _isExtracting = false;
        _updateStatus(
            'Searching ${_currentQueryIndex + 1}/${widget.queries.length}...');
        await Future.delayed(
            Duration(milliseconds: 1000 + Random().nextInt(500)));
        _loadNextQuery();
      } else {
        _updateStatus('Got ${_allResults.length} total results');
        await Future.delayed(const Duration(milliseconds: 400));
        _popWithResults(_allResults);
      }
    } catch (e) {
      print('DeepDrissySearchWebView: Error extracting results: $e');
      // On error, try next query or return what we have
      _currentQueryIndex++;
      if (_currentQueryIndex < widget.queries.length) {
        _isExtracting = false;
        _loadNextQuery();
      } else {
        _popWithResults(_allResults);
      }
    }
  }

  void _loadNextQuery() {
    if (_controller == null || _currentQueryIndex >= widget.queries.length) {
      return;
    }
    final encodedQuery =
        Uri.encodeComponent(widget.queries[_currentQueryIndex]);
    final searchUrl =
        'https://www.google.com/search?q=$encodedQuery&num=15';
    _controller!.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(searchUrl),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final encodedQuery =
        Uri.encodeComponent(widget.queries.first);
    final searchUrl =
        'https://www.google.com/search?q=$encodedQuery&num=15';
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
          onPressed: () => _popWithResults(_allResults),
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
          _updateStatus(
              'Loading page... (${_currentQueryIndex + 1}/${widget.queries.length})');
        }
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        if (_showCaptchaPrompt) {
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
        _updateStatus(
            'Page loaded, extracting... (${_currentQueryIndex + 1}/${widget.queries.length})');
        await _extractResults();
      },
      onReceivedError: (controller, request, error) {
        print(
            'DeepDrissySearchWebView: Load error: ${error.description}');
        // On error, try next query or return what we have
        _currentQueryIndex++;
        if (_currentQueryIndex < widget.queries.length) {
          _isExtracting = false;
          _loadNextQuery();
        } else {
          _popWithResults(_allResults);
        }
      },
    );
  }
}
