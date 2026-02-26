import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bavi/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class GoogleMapsWebView extends StatefulWidget {
  final String query;
  const GoogleMapsWebView({required this.query, super.key});

  @override
  State<GoogleMapsWebView> createState() => _GoogleMapsWebViewState();
}

class _GoogleMapsWebViewState extends State<GoogleMapsWebView> {
  InAppWebViewController? _controller;
  bool _isExtracting = false;
  bool _hasPopped = false;
  bool _clickedViewList = false;
  Timer? _timeoutTimer;
  double _progress = 0;
  bool _showCaptchaPrompt = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _popWithResults([]);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _popWithResults(List<LocalResultData> results) {
    if (_hasPopped) return;
    _hasPopped = true;
    _timeoutTimer?.cancel();
    print('[MapsWV] popping with ${results.length} results');
    if (mounted) Navigator.pop(context, results);
  }

  Future<bool> _isCaptchaPage() async {
    if (_controller == null) return false;
    final check = await _controller!.evaluateJavascript(source: '''
(function() {
  var b = document.body ? document.body.innerText : '';
  if (document.querySelector('#captcha-form,form[action*="sorry"]')) return 'yes';
  if (b.indexOf('unusual traffic') > -1 || b.indexOf('not a robot') > -1) return 'yes';
  if (document.querySelector('form[action*="consent"]')) return 'yes';
  return 'no';
})();
''');
    return (check ?? '').toString() == 'yes';
  }

  Future<void> _extractResults() async {
    if (_isExtracting || _hasPopped || _controller == null) return;
    _isExtracting = true;

    // Small delay for page to settle
    await Future.delayed(
        Duration(milliseconds: 2000 + Random().nextInt(500)));
    if (_hasPopped) return;

    // Check captcha
    if (await _isCaptchaPage()) {
      print('[MapsWV] CAPTCHA detected');
      _isExtracting = false;
      if (mounted) setState(() => _showCaptchaPrompt = true);
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        _popWithResults([]);
      });
      return;
    }

    try {
      // Try extracting place cards from current page
      final result = await _controller!.evaluateJavascript(source: _extractJS);
      print('[MapsWV] JS result: ${(result?.toString() ?? 'null').substring(0, min(300, (result?.toString() ?? 'null').length))}');

      if (result != null && result.toString() != 'null') {
        final decoded = jsonDecode(result.toString());

        // If JS returned results array → build LocalResultData and pop
        if (decoded is List && decoded.isNotEmpty) {
          final results = decoded.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value as Map<String, dynamic>;
            return LocalResultData(
              position: i + 1,
              title: (p['name'] as String?) ?? '',
              placeId: '',
              dataId: '',
              dataCid: '',
              gpsCoordinates: {},
              placeIdSearch: '',
              providerId: '',
              rating: _toDouble(p['rating']),
              reviews: (p['reviewCount'] as int?) ?? 0,
              price: '',
              type: (p['type'] as String?) ?? '',
              types: [],
              typeId: '',
              typeIds: [],
              address: (p['address'] as String?) ?? '',
              openState: (p['openState'] as String?) ?? '',
              hours: '',
              operatingHours: {},
              phone: (p['phone'] as String?) ?? '',
              website: '',
              snippet: '',
              images: ((p['imageUrl'] as String?) ?? '').isNotEmpty
                  ? [p['imageUrl'] as String]
                  : [],
              featuredReviews: const [],
            );
          }).toList();
          print('[MapsWV] extracted ${results.length} places');
          _popWithResults(results);
          return;
        }
      }

      // No results found — click "View list" if we haven't yet
      if (!_clickedViewList) {
        print('[MapsWV] no results on map view, clicking View list...');
        _clickedViewList = true;
        await _controller!.evaluateJavascript(source: r'''
(function(){
  var all = Array.from(document.querySelectorAll('button,[role="button"]'));
  var btn = all.find(function(b){
    var t = (b.innerText || b.getAttribute('aria-label') || '').toLowerCase();
    return t.includes('view list') || t.includes('list view') || t === 'list';
  });
  if (btn) btn.click();
})();
''');
        _isExtracting = false;
        return;
      }

      // Still nothing after View list — pop with empty
      print('[MapsWV] no results found after View list');
      _popWithResults([]);
    } catch (e) {
      print('[MapsWV] error: $e');
      _popWithResults([]);
    }
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ── JS — extract place cards from Google Maps Lite list view ───────────
  // Maps Lite uses .Nv2PK cards with button.hfpxzc (NOT anchor links).
  // Selectors confirmed from actual DOM dump:
  //   Name: .qBF1Pd / [class*="fontHeadlineSmall"]
  //   Rating: .MW4etd (text) or .ZkP5Je aria-label
  //   Reviews: .UY7F9 (e.g. "(61)")
  //   Type/Address: .W4Efsd spans separated by ·
  //   Phone: .UsdlK or a[href^="tel:"]
  //   Image: img[src*="http"]
  static const String _extractJS = r'''
(function(){
  var results = [];
  var seen = {};

  // ── Find cards ────────────────────────────────────────────────────────
  var cards = [];

  // Strategy 1: feed > article
  var feed = document.querySelector('[role="feed"]');
  if (feed) cards = Array.from(feed.querySelectorAll('[role="article"]'));

  // Strategy 2: any article
  if (cards.length === 0) cards = Array.from(document.querySelectorAll('[role="article"]'));

  // Strategy 3: known Maps Lite classes
  if (cards.length === 0) cards = Array.from(document.querySelectorAll('.Nv2PK,.THOPZb,.lI9IFe,.bfdHYd'));

  if (cards.length === 0) return 'null';

  // ── Extract from each card ────────────────────────────────────────────
  cards.forEach(function(card) {
    // Name — from specific class or aria-label on card
    var nameEl = card.querySelector('.qBF1Pd,[class*="fontHeadlineSmall"],.NrDZNb,h3,h2');
    var name = nameEl ? nameEl.innerText.trim() : '';
    if (!name) name = (card.getAttribute('aria-label') || '').split('\n')[0].trim();
    if (!name) {
      var lines = card.innerText.split('\n').map(function(l){return l.trim();})
                      .filter(function(l){return l.length > 1;});
      name = lines[0] || '';
    }
    if (!name || name.length < 2) return;

    // Deduplicate by name
    if (seen[name]) return;
    seen[name] = true;

    // Rating — from .MW4etd text or aria-label with "stars"
    var rating = 0;
    var mwEl = card.querySelector('.MW4etd');
    if (mwEl) { var m = mwEl.innerText.match(/[\d.]+/); if (m) rating = parseFloat(m[0]); }
    if (!rating) {
      var rEl = card.querySelector('.ZkP5Je,[role="img"][aria-label],[aria-label*="stars"],[aria-label*=" star"]');
      if (rEl) { var m2 = (rEl.getAttribute('aria-label')||'').match(/[\d.]+/); if (m2) rating = parseFloat(m2[0]); }
    }
    if (!rating) { var rt = card.innerText.match(/\b([1-5]\.[0-9])\b/); if (rt) rating = parseFloat(rt[1]); }

    // Review count — from .UY7F9 or parenthesized number
    var reviewCount = 0;
    var rcEl = card.querySelector('.UY7F9');
    if (rcEl) { var n2 = rcEl.innerText.replace(/[^\d]/g,''); if (n2) reviewCount = parseInt(n2) || 0; }
    if (!reviewCount) {
      var rcEl2 = card.querySelector('[aria-label*="review"]');
      if (rcEl2) { var n3 = rcEl2.innerText.replace(/[^\d]/g,''); if (n3) reviewCount = parseInt(n3) || 0; }
    }
    if (!reviewCount) { var rt2 = card.innerText.match(/\(([0-9][0-9,]*)\)/); if (rt2) reviewCount = parseInt(rt2[1].replace(/,/g,'')) || 0; }

    // Type & address — from .W4Efsd spans, split by ·
    var type = '', address = '';
    var wEls = card.querySelectorAll('.W4Efsd');
    for (var wi = 0; wi < wEls.length; wi++) {
      var t = wEls[wi].innerText.trim();
      if (!t || t === name) continue;
      // Skip if it's just rating/review text
      if (t.match(/^[\d.]+\s*\([\d,]+\)$/)) continue;
      var parts = t.split('\u00b7').map(function(s){return s.trim();}).filter(function(s){return s.length > 0;});
      for (var pi = 0; pi < parts.length; pi++) {
        var p = parts[pi];
        // Skip numeric-only parts (rating, review count)
        if (p.match(/^[\d.,()]+$/)) continue;
        if (!type) { type = p; continue; }
        if (!address) { address = p; continue; }
      }
      if (type && address) break;
    }
    // Fallback from text lines
    if (!type || !address) {
      var ls = card.innerText.split('\n').map(function(l){return l.trim();})
                   .filter(function(l){return l.length > 1 && l !== name && !l.match(/^[\d.]+$/) && !l.match(/^\([\d,]+\)$/);});
      if (!type && ls[0]) type = ls[0];
      if (!address && ls[1]) address = ls[1];
    }

    // Open state
    var openState = '';
    var openEl = card.querySelector('.eXlrNe,.YOGjf,.OSrXXb');
    if (openEl) openState = openEl.innerText.trim();
    // Also check for inline-styled spans with open/closed text
    if (!openState) {
      var spans = card.querySelectorAll('span[style*="color"]');
      for (var si = 0; si < spans.length; si++) {
        var st = spans[si].innerText.trim().toLowerCase();
        if (st.indexOf('open') > -1 || st.indexOf('close') > -1) {
          openState = spans[si].innerText.trim();
          break;
        }
      }
    }

    // Phone — from .UsdlK or tel: link
    var phone = '';
    var phoneEl = card.querySelector('.UsdlK');
    if (phoneEl) phone = phoneEl.innerText.trim();
    if (!phone) {
      var telLink = card.querySelector('a[href^="tel:"]');
      if (telLink) phone = telLink.innerText.trim() || telLink.href.replace('tel:','');
    }

    // Image
    var imgEl = card.querySelector('img[src*="http"]');
    var imageUrl = imgEl ? imgEl.src : '';

    results.push({name: name, rating: rating, reviewCount: reviewCount,
                  type: type, address: address, openState: openState,
                  phone: phone, imageUrl: imageUrl});
  });

  if (results.length === 0) return 'null';
  return JSON.stringify(results.slice(0, 10));
})();
''';

  @override
  Widget build(BuildContext context) {
    final encodedQuery = Uri.encodeComponent(widget.query);
    final searchUrl = 'https://www.google.com/maps/search/$encodedQuery';

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
          _showCaptchaPrompt ? 'Please verify below' : 'Searching Maps...',
          style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
        userAgent: '',
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: true,
        clearCache: false,
        thirdPartyCookiesEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        if (url.startsWith('intent://')) {
          try {
            final withoutScheme = url.substring('intent://'.length);
            final hashIdx = withoutScheme.indexOf('#Intent;');
            final path = hashIdx >= 0
                ? withoutScheme.substring(0, hashIdx)
                : withoutScheme;
            final schemeMatch = RegExp(r'scheme=(\w+)').firstMatch(url);
            final scheme = schemeMatch?.group(1) ?? 'https';
            await controller.loadUrl(
                urlRequest: URLRequest(url: WebUri('$scheme://$path')));
          } catch (_) {}
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (c) => _controller = c,
      onProgressChanged: (_, p) {
        if (mounted) setState(() => _progress = p / 100);
      },
      onLoadStop: (_, url) async {
        final cu = url?.toString() ?? '';
        print('[MapsWV] onLoadStop: $cu');
        if (_hasPopped) return;

        if (_showCaptchaPrompt) {
          if (cu.contains('maps') && !(await _isCaptchaPage())) {
            if (mounted) setState(() => _showCaptchaPrompt = false);
            _isExtracting = false;
            await _extractResults();
          }
          return;
        }

        await _extractResults();
      },
      onReceivedError: (_, request, error) {
        print('[MapsWV] error: ${error.description}');
      },
    );
  }
}
