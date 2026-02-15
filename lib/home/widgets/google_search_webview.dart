import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/short_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class GoogleSearchWebView extends StatefulWidget {
  final String query;

  const GoogleSearchWebView({required this.query, super.key});

  @override
  State<GoogleSearchWebView> createState() => _GoogleSearchWebViewState();
}

class _GoogleSearchWebViewState extends State<GoogleSearchWebView> {
  InAppWebViewController? _controller;
  bool _isExtracting = false;
  bool _hasPopped = false;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 25), () {
      _popWithResults([]);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
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

  Future<void> _extractResults() async {
    if (_isExtracting || _controller == null) return;
    _isExtracting = true;

    // Small random delay to appear more natural
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
    } catch(e) {
      return true;
    }
    if (url.startsWith('javascript:')) return true;
    if (url === '#' || url.charAt(0) === '#') return true;
    return false;
  }

  function cleanUrl(url) {
    if (url.indexOf('/url?') !== -1 || url.indexOf('google.com/url') !== -1) {
      try {
        var u = new URL(url);
        var q = u.searchParams.get('q') || u.searchParams.get('url');
        if (q && q.indexOf('http') === 0) return q;
      } catch(e) {}
    }
    return url;
  }

  function getSnippet(startEl) {
    var block = startEl;
    for (var i = 0; i < 10; i++) {
      if (!block.parentElement) break;
      block = block.parentElement;
      var cl = block.classList;
      if (cl && (cl.contains('g') || cl.contains('hlcw0c') || cl.contains('MjjYud'))) break;
      if (block.getAttribute('data-sokoban-container') !== null) break;
      if (block.getAttribute('data-hveid') !== null) break;
    }

    var selectors = [
      '.VwiC3b', '[data-sncf]', '.IsZvec', '.lEBKkf', '.ITZIwc',
      '.GI74Re', '.yDYNvb', '.LEwnzc', '.lyLwlc',
      '[style*="-webkit-line-clamp"]',
      'div[data-content-feature]',
      '.st', '.s'
    ];
    for (var s = 0; s < selectors.length; s++) {
      try {
        var el = block.querySelector(selectors[s]);
        if (el && el.innerText && el.innerText.trim().length > 15) {
          return el.innerText.trim();
        }
      } catch(e) {}
    }

    var titleText = (startEl.innerText || '').trim();
    var allEls = block.querySelectorAll('div, span, p');
    for (var j = 0; j < allEls.length; j++) {
      var t = (allEls[j].innerText || '').trim();
      if (t.length > 30 && t !== titleText && t.indexOf('http') !== 0) {
        if (t.length > 500) t = t.substring(0, 500);
        return t;
      }
    }
    return '';
  }

  // Strategy 1: h3-based (standard organic results)
  var allH3 = document.querySelectorAll('h3');
  for (var i = 0; i < allH3.length; i++) {
    var h3 = allH3[i];
    var title = (h3.innerText || '').trim();
    if (!title || title.length < 2) continue;

    var a = h3.closest('a');
    if (!a) {
      var p = h3.parentElement;
      for (var depth = 0; depth < 4 && p && !a; depth++) {
        a = p.querySelector('a[href]');
        if (!a) a = p.closest('a');
        p = p.parentElement;
      }
    }

    var url = a ? (a.href || '') : '';
    url = cleanUrl(url);

    if (!url || isGoogleInternal(url)) {
      var dataEl = h3.closest('[data-url]');
      if (dataEl) url = dataEl.getAttribute('data-url') || '';
    }

    if (!url || isGoogleInternal(url)) {
      var container = h3.parentElement;
      for (var d = 0; d < 5 && container; d++) {
        var links = container.querySelectorAll('a[href]');
        for (var li = 0; li < links.length; li++) {
          var candidate = cleanUrl(links[li].href || '');
          if (candidate && !isGoogleInternal(candidate)) {
            url = candidate;
            break;
          }
        }
        if (url && !isGoogleInternal(url)) break;
        container = container.parentElement;
      }
    }

    if (!url || isGoogleInternal(url)) continue;
    if (seen[url]) continue;
    seen[url] = true;

    results.push({
      url: url,
      title: title,
      excerpts: getSnippet(h3)
    });
  }

  // Strategy 2: data-hveid blocks
  if (results.length < 5) {
    var blocks = document.querySelectorAll('[data-hveid]');
    for (var b = 0; b < blocks.length; b++) {
      var block = blocks[b];
      var link = block.querySelector('a[href]');
      if (!link) continue;
      var href = cleanUrl(link.href || '');
      if (!href || isGoogleInternal(href) || seen[href]) continue;

      var textEl = block.querySelector('h3') || block.querySelector('[role="heading"]');
      var title2 = textEl ? (textEl.innerText || '').trim() : (link.innerText || '').trim();
      if (!title2 || title2.length < 3 || title2.length > 200) continue;

      seen[href] = true;
      results.push({
        url: href,
        title: title2,
        excerpts: getSnippet(textEl || link)
      });
    }
  }

  // Strategy 3: all external links fallback
  if (results.length < 3) {
    var allLinks = document.querySelectorAll('a[href]');
    for (var k = 0; k < allLinks.length; k++) {
      var lnk = allLinks[k];
      var lHref = cleanUrl(lnk.href || '');
      if (!lHref || isGoogleInternal(lHref) || seen[lHref]) continue;

      var lText = (lnk.innerText || '').trim();
      if (lText.length < 8 || lText.length > 200) continue;

      seen[lHref] = true;
      results.push({
        url: lHref,
        title: lText,
        excerpts: getSnippet(lnk)
      });

      if (results.length >= 15) break;
    }
  }

  return JSON.stringify(results.slice(0, 15));
})();
''');

      if (result != null && result != 'null') {
        final String jsonStr = result is String ? result : result.toString();
        final List<dynamic> parsed = jsonDecode(jsonStr);
        final extractedResults = parsed.map((e) {
          return ExtractedResultInfo(
            url: (e['url'] ?? '').toString(),
            title: (e['title'] ?? '').toString(),
            excerpts: (e['excerpts'] ?? '').toString(),
            thumbnailUrl: '',
          );
        }).toList();

        print(
            'GoogleSearchWebView: Extracted ${extractedResults.length} results');
        _popWithResults(extractedResults);
      } else {
        print('GoogleSearchWebView: No results extracted');
        _popWithResults([]);
      }
    } catch (e) {
      print('GoogleSearchWebView: Error extracting results: $e');
      _popWithResults([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encodedQuery = Uri.encodeComponent(widget.query);
    // Request more results per page so we don't need to scroll
    final searchUrl = 'https://www.google.com/search?q=$encodedQuery&num=15';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => _popWithResults([]),
        ),
        title: Text(
          _showCaptchaPrompt ? 'Please verify below' : 'Searching...',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        bottom: _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          // When CAPTCHA is detected, allow user interaction to solve it.
          // Otherwise, use IgnorePointer so casual taps don't navigate away.
          _showCaptchaPrompt
              ? _buildWebView(searchUrl)
              : IgnorePointer(child: _buildWebView(searchUrl)),
          if (_showCaptchaPrompt)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.amber.shade100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  'Google requires verification. Please complete it to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
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
        await _extractResults();
      },
      onReceivedError: (controller, request, error) {
        print('GoogleSearchWebView: Load error: ${error.description}');
        _popWithResults([]);
      },
    );
  }
}
