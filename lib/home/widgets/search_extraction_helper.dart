import 'dart:convert';
import 'package:bavi/models/short_video.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Shared extraction utilities used by both [GoogleSearchWebView] and
/// [DeepDrissySearchWebView] so that search-result parsing is always
/// identical between the two features.
class SearchExtractionHelper {
  SearchExtractionHelper._();

  // ---------------------------------------------------------------------------
  // CAPTCHA / consent detection
  // ---------------------------------------------------------------------------

  /// Returns true when the currently loaded page appears to be a CAPTCHA or
  /// Google consent gate rather than a real search-results page.
  /// Combines the checks from both webview implementations.
  static Future<bool> isCaptchaOrConsentPage(
    InAppWebViewController controller,
  ) async {
    final check = await controller.evaluateJavascript(source: '''
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

  // ---------------------------------------------------------------------------
  // Result extraction
  // ---------------------------------------------------------------------------

  /// Runs the 4-strategy JavaScript extraction against the current page and
  /// returns up to 15 [ExtractedResultInfo] objects.
  static Future<List<ExtractedResultInfo>> extractResultsFromPage(
    InAppWebViewController controller,
  ) async {
    final result = await controller.evaluateJavascript(source: '''
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

  // Strategy 1: New Google layout (2025+)
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
      try {
        final List<dynamic> parsed = jsonDecode(jsonStr);
        return parsed.map((e) {
          return ExtractedResultInfo(
            url: (e['url'] ?? '').toString(),
            title: (e['title'] ?? '').toString(),
            excerpts: (e['excerpts'] ?? '').toString(),
            thumbnailUrl: '',
          );
        }).toList();
      } catch (_) {}
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Scroll helper
  // ---------------------------------------------------------------------------

  /// Scrolls the page incrementally until organic result count stabilises.
  ///
  /// [maxSteps] — maximum scroll iterations (default 6, matching regular browse).
  /// [stepDelayMs] — milliseconds between scroll steps (default 400).
  /// [onStatus] — optional callback for status-text updates.
  static Future<void> scrollToLastOrganicResult(
    InAppWebViewController controller, {
    void Function(String)? onStatus,
    int maxSteps = 6,
    int stepDelayMs = 400,
  }) async {
    int lastKnownCount = 0;
    int stableRounds = 0;

    for (int step = 0; step < maxSteps; step++) {
      final countResult = await controller.evaluateJavascript(source: '''
(function() {
  var items = document.querySelectorAll('#rso .g h3, #search .g h3, .F0FGWb[role="heading"], [data-snf="GuLy6c"]');
  return items.length;
})();
''');
      final currentCount = int.tryParse(countResult?.toString() ?? '0') ?? 0;

      if (currentCount > 0) {
        onStatus?.call('Found $currentCount results');
      }

      if (currentCount == lastKnownCount && currentCount > 0) {
        stableRounds++;
        if (stableRounds >= 2) break;
      } else {
        stableRounds = 0;
      }
      lastKnownCount = currentCount;

      await controller.evaluateJavascript(source: '''
(function() {
  var items = document.querySelectorAll('#rso .g h3, .F0FGWb[role="heading"], [data-snf="GuLy6c"]');
  if (items.length > 0) {
    items[items.length - 1].scrollIntoView({ behavior: 'smooth', block: 'center' });
  } else {
    window.scrollBy({ top: window.innerHeight * 0.7, behavior: 'smooth' });
  }
})();
''');
      await Future.delayed(Duration(milliseconds: stepDelayMs));
    }
  }
}
