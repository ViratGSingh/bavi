import 'package:bavi/home/view/home_page.dart';
import 'package:bavi/home/widgets/tabs_view.dart';
import 'package:bavi/models/ad_blockers/yt_ad_blocker.dart';
import 'package:bavi/models/ad_blockers/gen_ad_blocker.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:bavi/app_database.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String? title;
  final String? tabId;
  final bool? isInitial;
  final bool? isIncognito;
  final bool showAppBar;
  final String? highlightText;

  const WebViewPage(
      {required this.url,
      this.title,
      this.tabId,
      this.isInitial,
      this.isIncognito,
      this.showAppBar = true,
      this.highlightText,
      super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late InAppWebViewController _controller;
  late PullToRefreshController _pullToRefreshController;
  bool isLoading = true;
  double progress = 0.0;
  late AppDatabase db;
  Timer? _saveTimer;
  String? _currentTabId;

  DateTime? _lastUserInteraction;
  bool _canGoForward = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    db = AppDatabase();

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
          backgroundColor: const Color(0xFF8A2BE2),
          color: const Color(0xFFDFFF00)),
      onRefresh: () async {
        await _controller.reload();
        _pullToRefreshController.endRefreshing();
      },
    );
  }

  String? getDomainFromUrl(String url) {
    try {
      List<String> values = url.trim().split(" ");
      String formattedValue = values.first;
      if ((values.length == 1 &&
              formattedValue.contains(".") &&
              formattedValue.length >= 4) ||
          (values.length == 1 &&
              formattedValue.contains("http") &&
              formattedValue.contains("://"))) {
        if (formattedValue.contains("https") == false &&
            formattedValue.contains("http") == false) {
          formattedValue = "https://${formattedValue}";
        }
      }
      final uri = Uri.parse(formattedValue);
      return uri.host.isNotEmpty ? uri.host : null;
    } catch (e) {
      return null;
    }
  }

  Widget _navIconButton({
    required IconData icon,
    double size = 18,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, size: size, color: color ?? Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  String _ensureHttps(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'https://www.google.com';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUrl.isEmpty) _currentUrl = _ensureHttps(widget.url);
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Compact URL / Navigation Bar
            Container(
              decoration: BoxDecoration(
                color:  Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.25),
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              
              child: Row(
                children: [
                  _navIconButton(
                    icon: Icons.close_rounded,
                    size: 22,
                    onPressed: () async {
                        Navigator.pop(context);
                      
                    },
                  ),
                  //const SizedBox(width: 2),
                  // URL pill
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () async {
                        // final currentUrl = await _controller.getUrl();
                        // final urlToCopy =
                        //     currentUrl?.toString() ?? widget.url;
                        // Clipboard.setData(ClipboardData(text: urlToCopy));
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   const SnackBar(
                        //       content: Text('Link copied'),
                        //       duration: Duration(seconds: 1)),
                        // );
                      },
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color:  Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon(
                            //   Icons.lock_outline_rounded,
                            //   size: 12,
                            //   color: Colors.grey.shade600,
                            // ),
                            // const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                getDomainFromUrl(_currentUrl) ?? 'website.com',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 6),
                  // _navIconButton(
                  //   icon: Iconsax.refresh_outline,
                  //   size: 18,
                  //   onPressed: () async {
                  //     await _controller.reload();
                  //     await _updateNavigationState();
                  //   },
                  // ),
                  _navIconButton(
                    icon: Iconsax.send_2_outline,
                    size: 22,
                    onPressed: () async {
                      final currentUrl = await _controller.getUrl();
                      Share.share(currentUrl?.toString() ?? widget.url);
                    },
                  ),
                ],
              ),
            ),
            // Progress bar
            if (progress < 1.0)
              LinearProgressIndicator(
                value: progress,
                color: const Color(0xFF8A2BE2),
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            // WebView content
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_ensureHttps(widget.url)),
                  headers: {
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
                  },
                ),
                shouldInterceptRequest: (controller, request) async {
                  try {
                    final requestUrl = request.url.toString();
                    final requestHost = request.url.host.toLowerCase();

                    if (requestHost.contains('youtube.com')) {
                      if (YouTubeAdBlocker.shouldBlockUrl(requestUrl)) {
                        print('Blocked YouTube ad request: $requestUrl');
                        return WebResourceResponse(
                          contentType: 'text/plain',
                          data: Uint8List.fromList([]),
                        );
                      }
                    }
                  } catch (e) {
                    // Silent fail
                  }
                  return null;
                },

                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onReceivedError: (controller, request, error) {
                  print('WebView error: ${error.type} - ${error.description} for ${request.url}');
                },
                onReceivedHttpError: (controller, request, response) {
                  print('WebView HTTP error: ${response.statusCode} for ${request.url}');
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    isLoading = true;
                    if (url != null) {
                      _currentUrl = url.toString();
                    }
                  });
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    isLoading = false;
                    if (url != null) {
                      _currentUrl = url.toString();
                    }
                  });
                  _pullToRefreshController.endRefreshing();

                  final urlString = url.toString();

                  try {
                    if (urlString.contains('youtube.com')) {
                      await controller.evaluateJavascript(
                          source: YouTubeAdBlocker.getCosmeticFilterScript());
                    }

                    await controller.evaluateJavascript(
                        source: GeneralAdBlocker.getAdRemovalScript());

                    await controller.evaluateJavascript(source: """
        (function() {
          window.open = function() {
            console.log('Blocked popup');
            return {
              closed: false,
              close: function() {},
              focus: function() {}
            };
          };

          var isLegitimateClick = false;

          document.addEventListener('mousedown', function(e) {
            var target = e.target;
            if (target.tagName === 'A' ||
                target.tagName === 'BUTTON' ||
                target.tagName === 'VIDEO' ||
                target.closest('a') ||
                target.closest('button') ||
                target.closest('video') ||
                target.closest('[onclick]')) {
              isLegitimateClick = true;
              setTimeout(function() { isLegitimateClick = false; }, 100);
            }
          }, true);

          ['click', 'mousedown', 'touchstart'].forEach(function(eventType) {
            document.addEventListener(eventType, function(e) {
              var target = e.target;

              if ((target === document.body || target === document.documentElement) &&
                  !isLegitimateClick) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                return false;
              }
            }, true);
          });

          document.querySelectorAll('meta[http-equiv="refresh"]').forEach(function(meta) {
            meta.remove();
          });

          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              mutation.addedNodes.forEach(function(node) {
                if (node.tagName === 'META' &&
                    node.getAttribute('http-equiv') === 'refresh') {
                  node.remove();
                }
              });
            });
          });
          observer.observe(document.head || document.documentElement, {
            childList: true,
            subtree: true
          });
        })();
      """);

                    print('Applied smart protection');
                  } catch (e) {
                    print('Error applying filters: $e');
                  }

                  // Highlight and scroll to answer text if provided
                  if (widget.highlightText != null &&
                      widget.highlightText!.isNotEmpty) {
                    final escapedText = widget.highlightText!
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim()
                        .replaceAll('\\', '\\\\')
                        .replaceAll("'", "\\'")
                        .replaceAll('\n', ' ')
                        .replaceAll('\r', ' ');
                    await controller.evaluateJavascript(source: """
        (function() {
          var rawText = '$escapedText';

          // Build search phrases: split into sentences, then progressively shorter word chunks
          function buildPhrases(text) {
            var phrases = [];
            // Split into sentences and take each as a candidate
            var sentences = text.split(/[.!?]+/).map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 10; });
            for (var i = 0; i < sentences.length; i++) {
              phrases.push(sentences[i]);
            }
            // Also try word-based chunks from the start
            var words = text.split(/\\s+/);
            for (var len = Math.min(words.length, 12); len >= 3; len--) {
              var chunk = words.slice(0, len).join(' ');
              if (chunk.length > 10) phrases.push(chunk);
            }
            return phrases;
          }

          // Use window.find() to locate text across DOM nodes, then highlight the selection
          function findAndHighlight(text) {
            // Clear any existing selection
            window.getSelection().removeAllRanges();
            // window.find(text, caseSensitive, backwards, wrapAround)
            if (window.find && window.find(text, false, false, true)) {
              var sel = window.getSelection();
              if (sel && sel.rangeCount > 0) {
                try {
                  var range = sel.getRangeAt(0);
                  var mark = document.createElement('mark');
                  mark.style.backgroundColor = '#DFFF00';
                  mark.style.padding = '2px 4px';
                  mark.style.borderRadius = '3px';
                  mark.style.color = '#000';
                  range.surroundContents(mark);
                  sel.removeAllRanges();
                  mark.scrollIntoView({ behavior: 'smooth', block: 'center' });
                  return true;
                } catch(e) {
                  // surroundContents fails if range spans multiple elements
                  // Just scroll to the selection instead
                  try {
                    var rect = sel.getRangeAt(0).getBoundingClientRect();
                    window.scrollTo({ top: window.scrollY + rect.top - window.innerHeight / 3, behavior: 'smooth' });
                    // Add a temporary highlight overlay
                    var overlay = document.createElement('div');
                    overlay.style.cssText = 'position:absolute;background:#DFFF00;opacity:0.4;pointer-events:none;z-index:99999;border-radius:3px;transition:opacity 3s;';
                    overlay.style.top = (window.scrollY + rect.top - 2) + 'px';
                    overlay.style.left = (rect.left - 2) + 'px';
                    overlay.style.width = (rect.width + 4) + 'px';
                    overlay.style.height = (rect.height + 4) + 'px';
                    document.body.appendChild(overlay);
                    setTimeout(function() { overlay.style.opacity = '0'; }, 3000);
                    setTimeout(function() { overlay.remove(); }, 6000);
                    sel.removeAllRanges();
                    return true;
                  } catch(e2) {}
                }
              }
            }
            return false;
          }

          function attempt() {
            var phrases = buildPhrases(rawText);
            for (var i = 0; i < phrases.length; i++) {
              if (findAndHighlight(phrases[i])) return true;
            }
            return false;
          }

          // Try immediately
          if (!attempt()) {
            // Retry after 1s for dynamically loaded content
            setTimeout(function() {
              if (!attempt()) {
                // Final retry after 3s
                setTimeout(function() { attempt(); }, 2000);
              }
            }, 1000);
          }
        })();
      """);
                  }

                  await _updateNavigationState();
                },
                onProgressChanged: (controller, progressValue) {
                  setState(() {
                    progress = (progressValue / 100);
                  });
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (url != null) {
                    setState(() {
                      _currentUrl = url.toString();
                    });
                  }
                },

                shouldOverrideUrlLoading:
                    (controller, navigationAction) async {
                  var uri = navigationAction.request.url;
                  var url = uri.toString();

                  print('Navigation attempt: $url');
                  print('Type: ${navigationAction.navigationType}');
                  print('Has gesture: ${navigationAction.hasGesture}');

                  if (url.toLowerCase().contains('doubleclick.net') ||
                      url.toLowerCase().contains('googlesyndication.com') ||
                      url.toLowerCase().contains('adservice.google.com') ||
                      url.toLowerCase().contains('googleadservices.com') ||
                      url.toLowerCase().contains('adnxs.com') ||
                      url.toLowerCase().contains('criteo.com') ||
                      url.toLowerCase().contains('outbrain.com') ||
                      url.toLowerCase().contains('taboola.com')) {
                    print('Blocked ad domain navigation');
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (navigationAction.isForMainFrame) {
                    if (navigationAction.navigationType ==
                            NavigationType.OTHER ||
                        navigationAction.navigationType ==
                            NavigationType.RELOAD) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    if (navigationAction.navigationType ==
                            NavigationType.LINK_ACTIVATED ||
                        navigationAction.hasGesture == true) {
                      _lastUserInteraction = DateTime.now();
                      return NavigationActionPolicy.ALLOW;
                    }

                    if (navigationAction.navigationType ==
                        NavigationType.FORM_SUBMITTED) {
                      if (navigationAction.hasGesture == true) {
                        _lastUserInteraction = DateTime.now();
                        return NavigationActionPolicy.ALLOW;
                      }
                    }

                    if (navigationAction.navigationType ==
                            NavigationType.OTHER &&
                        navigationAction.hasGesture != true) {
                      if (_lastUserInteraction != null) {
                        var timeSinceInteraction =
                            DateTime.now().difference(_lastUserInteraction!);
                        if (timeSinceInteraction.inSeconds > 2) {
                          print('Blocked automatic redirect to: $url');

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Blocked automatic redirect'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                    }

                    if (navigationAction.navigationType ==
                        NavigationType.BACK_FORWARD) {
                      return NavigationActionPolicy.ALLOW;
                    }
                  }

                  return NavigationActionPolicy.ALLOW;
                },

                onCreateWindow: (controller, createWindowAction) async {
                  print(
                      'Blocked popup window: ${createWindowAction.request.url}');
                  return false;
                },

                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                  return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED);
                },

                initialSettings: InAppWebViewSettings(
                  contentBlockers: [
                    ContentBlocker(
                      trigger: ContentBlockerTrigger(
                        urlFilter: ".*",
                        ifDomain: [
                          "*doubleclick.net",
                          "*googlesyndication.com",
                          "*adservice.google.com",
                          "*googleadservices.com",
                          "*google-analytics.com",
                          "*googletagmanager.com",
                          "*googletagservices.com",
                          "*outbrain.com",
                          "*taboola.com",
                          "*criteo.com",
                          "*advertising.com",
                          "*adnxs.com",
                          "*media.net",
                        ],
                      ),
                      action: ContentBlockerAction(
                        type: ContentBlockerActionType.BLOCK,
                      ),
                    ),
                  ],
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                  useShouldOverrideUrlLoading: true,
                  useShouldInterceptRequest: true,
                  useOnLoadResource: false,
                  allowContentAccess: true,
                  allowFileAccess: true,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  mixedContentMode:
                      MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  thirdPartyCookiesEnabled: true,
                  cacheEnabled: true,
                ),
              ),
            ),
            // Safari-style bottom action bar
            Container(
              decoration: BoxDecoration(
                color:  Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.25),
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 22,
                    onPressed: () async {
                      _lastUserInteraction = DateTime.now();
                      if (await _controller.canGoBack()) {
                        await _controller.goBack();
                        await _updateNavigationState();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  SizedBox(width: 6),
                  _navIconButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    size: 22,
                    color: _canGoForward
                        ? Colors.black87
                        : Colors.grey.withOpacity(0.3),
                    onPressed: _canGoForward
                        ? () async {
                            _lastUserInteraction = DateTime.now();
                            await _controller.goForward();
                            await _updateNavigationState();
                          }
                        : null,
                  ),
                  // // Tabs button
                  // GestureDetector(
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute<void>(
                  //         builder: (BuildContext context) =>
                  //             const TabsViewPage(),
                  //       ),
                  //     );
                  //   },
                  //   child: Icon(
                  //     Icons.copy_rounded,
                  //     size: 22,
                  //     color: Colors.grey.shade500,
                  //   ),
                  // ),
                  // // Center "+" button
                  // GestureDetector(
                  //   onTap: () async {
                  //     final currentUrl = await _controller.getUrl();
                  //     Share.share(currentUrl?.toString() ?? widget.url);
                  //   },
                  //   child: Container(
                  //     width: 120,
                  //     height: 42,
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.withOpacity(0.18),
                  //       borderRadius: BorderRadius.circular(21),
                  //     ),
                  //     child: Center(
                  //       child: Icon(
                  //         Icons.add,
                  //         size: 26,
                  //         color: Colors.grey.shade600,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // // Menu button
                  // GestureDetector(
                  //   onTap: () => _showBrowserMenu(context),
                  //   child: Container(
                  //     width: 42,
                  //     height: 42,
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.withOpacity(0.18),
                  //       borderRadius: BorderRadius.circular(21),
                  //     ),
                  //     child: Center(
                  //       child: Icon(
                  //         Icons.keyboard_arrow_up_rounded,
                  //         size: 26,
                  //         color: Colors.grey.shade600,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTabWithScreenshot(String url) async {
    try {
      final title = await _controller.getTitle();

      final screenshot = await _controller.takeScreenshot();

      if (screenshot != null) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(screenshot);
        final tabId = widget.tabId ?? _currentTabId;
        if (tabId != null) {
          await db.updateTab(
            widget.tabId!,
            TabsCompanion(
              title: Value(title ?? 'Untitled'),
              url: Value(url),
              imagePath: Value(filePath),
              updatedAt: Value(DateTime.now()),
            ),
          );
          debugPrint('Tab updated: $title');
        } else {
          final insertedTab = await db.insertTab(TabsCompanion.insert(
            title: Value(title ?? 'Untitled'),
            url: url,
            imagePath: Value(filePath),
            isIncognito: const Value(false),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
          _currentTabId = insertedTab.toString();
          debugPrint('Tab saved: $title');
        }
      } else {
        debugPrint('Screenshot not captured, tab not saved.');
      }
    } catch (e) {
      debugPrint('Error saving tab: $e');
    }
  }

  void _showBrowserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation bar (back, forward, domain, copy, reload)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (await _controller.canGoBack()) {
                          await _controller.goBack();
                        }
                      },
                      child: Icon(Icons.chevron_left_rounded,
                          size: 28, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (await _controller.canGoForward()) {
                          await _controller.goForward();
                        }
                      },
                      child: Icon(Icons.chevron_right_rounded,
                          size: 28, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          getDomainFromUrl(_currentUrl) ?? 'website.com',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final currentUrl = await _controller.getUrl();
                        Clipboard.setData(ClipboardData(
                            text: currentUrl?.toString() ?? _currentUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Link copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: Icon(Icons.link_rounded,
                          size: 22, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _controller.reload();
                      },
                      child: Icon(Icons.refresh_rounded,
                          size: 22, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Action buttons row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMenuAction(Icons.search_rounded, 'Find on Page',
                        () {
                      Navigator.pop(ctx);
                    }),
                    _buildMenuAction(Icons.bookmark_outline_rounded, 'Bookmark',
                        () async {
                      final title = await _controller.getTitle();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Bookmarked: ${title ?? 'Page'}'),
                              duration: const Duration(seconds: 1)),
                        );
                      }
                    }),
                    _buildMenuAction(Icons.push_pin_outlined, 'Pin', () {
                      Navigator.pop(ctx);
                    }),
                    _buildMenuAction(Icons.ios_share_rounded, 'Share',
                        () async {
                      Navigator.pop(ctx);
                      final currentUrl = await _controller.getUrl();
                      Share.share(currentUrl?.toString() ?? _currentUrl);
                    }),
                  ],
                ),
              ),
              // Menu list items
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Colors.grey.shade300),
                    _buildMenuItem(
                      icon: Icons.text_fields_rounded,
                      label: 'Display Options',
                      trailing: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade500),
                      onTap: () => Navigator.pop(ctx),
                    ),
                    Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Colors.grey.shade300),
                    _buildMenuItem(
                      icon: Icons.translate_rounded,
                      label: 'Translate',
                      onTap: () => Navigator.pop(ctx),
                    ),
                    Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Colors.grey.shade300),
                    _buildMenuItem(
                      icon: Icons.article_outlined,
                      label: 'Reader Mode',
                      onTap: () => Navigator.pop(ctx),
                    ),
                    Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Colors.grey.shade300),
                    _buildMenuItem(
                      icon: Icons.open_in_browser_rounded,
                      label: 'Open in Browser',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final currentUrl = await _controller.getUrl();
                        if (currentUrl != null) {
                          await launchUrl(currentUrl,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Close button
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Close Tab',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(icon, color: Colors.black87, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(icon, color: Colors.black87, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _updateNavigationState() async {
    final canGoForward = await _controller.canGoForward();

    if (mounted) {
      setState(() {
        _canGoForward = canGoForward;
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

//Basic

class BasicBrowserView extends StatefulWidget {
  final String url;
  const BasicBrowserView({super.key, required this.url});

  @override
  State<BasicBrowserView> createState() => _BasicBrowserViewState();
}

class _BasicBrowserViewState extends State<BasicBrowserView> {
  String url = '';
  String title = '';
  double progress = 0;
  bool? isSecure;
  InAppWebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    url = widget.url;
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
      shouldInterceptRequest: (controller, request) async {
        try {
          final requestUrl = request.url.toString();
          final requestHost = request.url.host.toLowerCase();

          if (requestHost.contains('youtube.com') ||
              requestHost.contains('googlevideo.com')) {
            if (YouTubeAdBlocker.shouldBlockUrl(requestUrl)) {
              print('Blocked YouTube ad request: $requestUrl');
              return WebResourceResponse(
                contentType: 'text/plain',
                data: Uint8List.fromList([]),
              );
            }
          }
        } catch (e) {
          // Silent fail
        }
        return null;
      },
      initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          safeBrowsingEnabled: true,
          isFraudulentWebsiteWarningEnabled: true),
      onWebViewCreated: (controller) async {
        webViewController = controller;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await controller.startSafeBrowsing();
        }
      },
      onLoadStart: (controller, url) {
        if (url != null) {
          setState(() {
            this.url = url.toString();
            isSecure = urlIsSecure(url);
          });
        }
      },
      onLoadStop: (controller, url) async {
        if (url != null) {
          setState(() {
            this.url = url.toString();
          });
        }

        final sslCertificate = await controller.getCertificate();
        setState(() {
          isSecure =
              sslCertificate != null || (url != null && urlIsSecure(url));
        });
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) {
          setState(() {
            this.url = url.toString();
          });
        }
      },
      onTitleChanged: (controller, title) {
        if (title != null) {
          setState(() {
            this.title = title;
          });
        }
      },
      onProgressChanged: (controller, progress) {
        setState(() {
          this.progress = progress / 100;
        });
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        if (url != null) {
          final scheme = url.scheme;
          if (![
            'http',
            'https',
            'file',
            'chrome',
            'data',
            'javascript',
            'about'
          ].contains(scheme)) {
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
              return NavigationActionPolicy.CANCEL;
            }
          }

          if (navigationAction.isForMainFrame &&
              (scheme == 'http' || scheme == 'https')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewPage(
                  url: url.toString(),
                  isInitial: false,
                ),
              ),
            );
            return NavigationActionPolicy.CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  void handleClick(int item) async {
    switch (item) {
      case 0:
        await InAppBrowser.openWithSystemBrowser(url: WebUri(url));
        break;
      case 1:
        await webViewController?.clearCache();
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await webViewController?.clearHistory();
        }
        setState(() {});
        break;
    }
  }

  static bool urlIsSecure(Uri url) {
    return (url.scheme == "https") || isLocalizedContent(url);
  }

  static bool isLocalizedContent(Uri url) {
    return (url.scheme == "file" ||
        url.scheme == "chrome" ||
        url.scheme == "data" ||
        url.scheme == "javascript" ||
        url.scheme == "about");
  }
}
