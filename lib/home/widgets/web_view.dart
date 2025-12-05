import 'package:bavi/home/view/home_page.dart';
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
import 'package:url_launcher/url_launcher.dart'; // your Drift database file

class WebViewPage extends StatefulWidget {
  final String url;
  final String? title;
  final String? tabId;
  final bool? isInitial;
  final bool? isIncognito;
  final bool showAppBar;

  const WebViewPage(
      {required this.url,
      this.title,
      this.tabId,
      this.isInitial,
      this.isIncognito,
      this.showAppBar = true,
      super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late InAppWebViewController _controller;
  late PullToRefreshController _pullToRefreshController; // ✅ add this
  bool isLoading = true;
  double progress = 0.0;
  late AppDatabase db; // Drift database instance
  Timer? _saveTimer;
  String? _currentTabId;

  // Add these to your State class
  DateTime? _lastUserInteraction;
  bool _canGoForward = false;

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
        //final url = await _controller.getUrl();
        // if (widget.isIncognito != true) {
        //   await _saveTabWithScreenshot(url?.toString() ?? widget.url);
        // }
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        bottomSheet: Container(
          //height: 240,
          //constraints: BoxConstraints(maxHeight: 100, minHeight: 100),

          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Top Navigation Bar
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black87,
                      ),
                      onPressed: () async {
                        _lastUserInteraction = DateTime.now();
                        if (await _controller.canGoBack()) {
                          await _controller.goBack();
                          await _updateNavigationState();
                        } else {
                          // No history - close the WebView page
                          Navigator.pop(context);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: _canGoForward
                            ? Colors.black87
                            : Colors.grey.withOpacity(0.3),
                      ),
                      onPressed: _canGoForward
                          ? () async {
                              _lastUserInteraction = DateTime.now();
                              await _controller.goForward();
                              await _updateNavigationState();
                            }
                          : null,
                    ),
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                getDomainFromUrl(widget.url) ?? 'website.com',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.link_2_outline,
                          size: 20, color: Colors.black87),
                      onPressed: () async {
                        final currentUrl = await _controller.getUrl();
                        final urlToCopy = currentUrl?.toString() ?? widget.url;
                        Clipboard.setData(ClipboardData(text: urlToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Link copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.refresh_outline,
                          size: 20, color: Colors.black87),
                      onPressed: () async {
                        await _controller.reload();
                        await _updateNavigationState();
                      },
                    ),
                  ],
                ),
              ),
              // const Spacer(),
              // // Action Buttons Grid
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     _buildActionButton(
              //         Iconsax.search_normal_1_outline, "Find on Page", () {
              //       // TODO: Implement find on page
              //     }),
              //     _buildActionButton(Iconsax.note_text_outline, "Summarize",
              //         () {
              //       // TODO: Implement summarize
              //     }),
              //     _buildActionButton(Iconsax.paintbucket_outline, "Pin", () {
              //       // TODO: Implement pin
              //     }),
              //     _buildActionButton(Iconsax.export_outline, "Share", () {
              //       Share.share(widget.url);
              //     }),
              //   ],
              // ),
              //const SizedBox(height: 8),
            ],
          ),
        ),
        // appBar: widget.showAppBar
        //     ? AppBar(
        //         titleSpacing: 0,
        //         backgroundColor: Colors.white,
        //         surfaceTintColor: Colors.white,
        //         elevation: 4,
        //         shadowColor: Colors.black.withOpacity(0.2),
        //         leadingWidth: 40,
        //         centerTitle: true,
        //         //state.status == HomePageStatus.idle ? true : false,
        //         leading: Padding(
        //           padding: const EdgeInsets.only(left: 0),
        //           child: InkWell(
        //             onTap: () {
        //               if (widget.isInitial == null ||
        //                   widget.isInitial == false) {
        //                 Navigator.pop(context);
        //               } else {
        //                 Navigator.push(
        //                   context,
        //                   MaterialPageRoute<void>(
        //                     builder: (BuildContext context) => const HomePage(),
        //                   ),
        //                   //ModalRoute.withName('/home'),
        //                 );
        //               }
        //             },
        //             child: Container(
        //               width: 32,
        //               height: 32,
        //               decoration: BoxDecoration(
        //                 //color: Color(0xFFDFFF00),
        //                 shape: BoxShape.circle,
        //                 //border: Border.all()
        //               ),
        //               padding: EdgeInsets.fromLTRB(1, 0, 2, 0),
        //               child: Center(
        //                 child: Icon(
        //                   Icons.arrow_back_ios,
        //                   color: Colors.black,
        //                   size: 20,
        //                 ),
        //               ),
        //             ),
        //           ),
        //         ),

        //         title: Text(
        //           getDomainFromUrl(widget.url) ?? 'Web View',
        //           style: const TextStyle(
        //             fontSize: 16,
        //             fontWeight: FontWeight.bold,
        //             color: Colors.black,
        //           ),
        //         ),
        //         actions: [
        //           Padding(
        //             padding: const EdgeInsets.only(right: 6),
        //             child: InkWell(
        //               onTap: () {
        //                 String? currentUrl = widget.url;
        //                 if (currentUrl != "") {
        //                   Share.share(currentUrl);
        //                 } else {
        //                   ScaffoldMessenger.of(context).showSnackBar(
        //                     const SnackBar(
        //                       content: Text('Unable to share link'),
        //                       duration: Duration(seconds: 2),
        //                     ),
        //                   );
        //                 }
        //               },
        //               child: Container(
        //                 width: 32,
        //                 height: 32,
        //                 decoration: BoxDecoration(
        //                     // borderRadius: BorderRadius.circular(18),
        //                     // color: Color(0xFFDFFF00),
        //                     // border: Border.all()
        //                     ),
        //                 child: Center(
        //                   child: Icon(
        //                     Iconsax.send_2_outline,
        //                     color: Colors.black,
        //                     size: 20,
        //                   ),
        //                 ),
        //               ),
        //             ),
        //           ),
        //           // Padding(
        //           //   padding: const EdgeInsets.only(right: 6),
        //           //   child: InkWell(
        //           //     onTap: () async {
        //           //       setState(() {
        //           //         isLoading = true;
        //           //         progress = 0.0;
        //           //       });
        //           //       try {
        //           //         await _controller.reload();
        //           //         final url = await _controller.getUrl();
        //           //         await _saveTabWithScreenshot(url?.toString() ?? widget.url);
        //           //       } catch (e) {
        //           //         debugPrint('❌ Error refreshing: $e');
        //           //       } finally {
        //           //         setState(() {
        //           //           isLoading = false;
        //           //         });
        //           //       }
        //           //     },
        //           //     child: Container(
        //           //       width: 32,
        //           //       height: 32,
        //           //       decoration: BoxDecoration(
        //           //           // borderRadius: BorderRadius.circular(18),
        //           //           // color: Color(0xFFDFFF00),
        //           //           // border: Border.all()
        //           //           ),
        //           //       child: Center(
        //           //         child: Icon(
        //           //           Iconsax.refresh_outline,
        //           //           color: Colors.black,
        //           //           size: 20,
        //           //         ),
        //           //       ),
        //           //     ),
        //           //   ),
        //           // ),
        //         ],
        //       )
        //     : null,
        body: Stack(
          children: [
            //BasicBrowserView(url: widget.url),
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.url),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
                },
              ),
              shouldInterceptRequest: (controller, request) async {
                try {
                  final requestUrl = request.url.toString();
                  final requestHost = request.url.host.toLowerCase();

                  // // Check general ad blocking (includes all major ad networks)
                  // if (GeneralAdBlocker.shouldBlockRequest(
                  //     requestUrl, requestHost)) {
                  //   print('Blocked ad request: $requestHost');
                  //   return WebResourceResponse(
                  //     contentType: 'text/plain',
                  //     data: Uint8List.fromList([]),
                  //   );
                  // }

                  //YouTube-specific blocking
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
              onLoadStart: (controller, url) {
                setState(() {
                  isLoading = true;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  isLoading = false;
                });
                _pullToRefreshController.endRefreshing();

                final urlString = url.toString();

                try {
                  // Apply YouTube filters for YouTube pages
                  if (urlString.contains('youtube.com')) {
                    await controller.evaluateJavascript(
                        source: YouTubeAdBlocker.getCosmeticFilterScript());
                  }

                  // Apply general ad removal for all pages
                  await controller.evaluateJavascript(
                      source: GeneralAdBlocker.getAdRemovalScript());

                  // Anti-redirect protection (less aggressive, allows real clicks)
                  await controller.evaluateJavascript(source: """
        (function() {
          // Override window.open completely
          window.open = function() {
            console.log('❌ Blocked popup');
            return {
              closed: false,
              close: function() {},
              focus: function() {}
            };
          };
          
          // Track if user is clicking on a legitimate element
          var isLegitimateClick = false;
          
          // Mark legitimate clicks (on links, buttons, videos)
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
          
          // Block clicks only on document/body (ad trick)
          ['click', 'mousedown', 'touchstart'].forEach(function(eventType) {
            document.addEventListener(eventType, function(e) {
              var target = e.target;
              
              // Only block if clicking directly on body/html
              if ((target === document.body || target === document.documentElement) && 
                  !isLegitimateClick) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                console.log('❌ Blocked background click redirect');
                return false;
              }
            }, true);
          });
          
          // Block meta refresh redirects
          document.querySelectorAll('meta[http-equiv="refresh"]').forEach(function(meta) {
            meta.remove();
            console.log('❌ Blocked meta refresh');
          });
          
          // Watch for new meta refresh tags
          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              mutation.addedNodes.forEach(function(node) {
                if (node.tagName === 'META' && 
                    node.getAttribute('http-equiv') === 'refresh') {
                  node.remove();
                  console.log('❌ Blocked dynamic meta refresh');
                }
              });
            });
          });
          observer.observe(document.head || document.documentElement, {
            childList: true,
            subtree: true
          });
          
          console.log('✅ Smart anti-redirect protection enabled');
        })();
      """);

                  print('Applied smart protection');
                } catch (e) {
                  print('Error applying filters: $e');
                }

                // // Screenshot logic
                // _saveTimer?.cancel();
                // _saveTimer = Timer(const Duration(seconds: 1), () async {
                //   if (widget.isIncognito != true) {
                //     await _saveTabWithScreenshot(url.toString());
                //   }
                // });

                // Update navigation state
                await _updateNavigationState();
              },
              onProgressChanged: (controller, progressValue) {
                setState(() {
                  progress = (progressValue / 100);
                });
              },

              // SMARTER: Allow user clicks, block automatic redirects
              // SMARTER: Allow user clicks, block automatic redirects, open legit redirects in new page
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url;
                var url = uri.toString();

                print('Navigation attempt: $url');
                print('Type: ${navigationAction.navigationType}');
                print('Has gesture: ${navigationAction.hasGesture}');

                // Always block ad domains
                if (url.toLowerCase().contains('doubleclick.net') ||
                    url.toLowerCase().contains('googlesyndication.com') ||
                    url.toLowerCase().contains('adservice.google.com') ||
                    url.toLowerCase().contains('googleadservices.com') ||
                    url.toLowerCase().contains('adnxs.com') ||
                    url.toLowerCase().contains('criteo.com') ||
                    url.toLowerCase().contains('outbrain.com') ||
                    url.toLowerCase().contains('taboola.com')) {
                  print('❌ Blocked ad domain navigation');
                  return NavigationActionPolicy.CANCEL;
                }

                // For main frame navigation
                if (navigationAction.isForMainFrame) {
                  // Allow initial load and reloads
                  if (navigationAction.navigationType == NavigationType.OTHER ||
                      navigationAction.navigationType ==
                          NavigationType.RELOAD) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  // User clicked a link - allow navigation in same page
                  if (navigationAction.navigationType ==
                          NavigationType.LINK_ACTIVATED ||
                      navigationAction.hasGesture == true) {
                    print('✅ User clicked link - navigating in same page');
                    _lastUserInteraction = DateTime.now();
                    return NavigationActionPolicy.ALLOW;
                  }

                  // Form submissions with user gesture - allow in same page
                  if (navigationAction.navigationType ==
                      NavigationType.FORM_SUBMITTED) {
                    if (navigationAction.hasGesture == true) {
                      print('✅ Form submission - navigating in same page');
                      _lastUserInteraction = DateTime.now();
                      return NavigationActionPolicy.ALLOW;
                    }
                  }

                  // Block automatic navigation (OTHER type without gesture)
                  if (navigationAction.navigationType == NavigationType.OTHER &&
                      navigationAction.hasGesture != true) {
                    // Check if this is likely an automatic redirect
                    if (_lastUserInteraction != null) {
                      var timeSinceInteraction =
                          DateTime.now().difference(_lastUserInteraction!);
                      // If more than 2 seconds since last interaction, it's likely automatic
                      if (timeSinceInteraction.inSeconds > 2) {
                        print('❌ Blocked automatic redirect to: $url');

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

                  // Allow back/forward navigation
                  if (navigationAction.navigationType ==
                      NavigationType.BACK_FORWARD) {
                    return NavigationActionPolicy.ALLOW;
                  }
                }

                return NavigationActionPolicy.ALLOW;
              },

              // Block new windows absolutely
              onCreateWindow: (controller, createWindowAction) async {
                print(
                    '❌ Blocked popup window: ${createWindowAction.request.url}');
                return false;
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
                userAgent:
                    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
            ),
            if (progress < 1.0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  color: Color(0xFF8A2BE2),
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTabWithScreenshot(String url) async {
    try {
      // Get page title
      final title = await _controller.getTitle();

      final screenshot = await _controller.takeScreenshot();

      // Save only if screenshot is available
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
          debugPrint('🔁 Tab updated: $title');
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
          debugPrint('✅ Tab saved: $title');
        }
      } else {
        debugPrint('⚠️ Screenshot not captured, tab not saved.');
      }
    } catch (e) {
      debugPrint('❌ Error saving tab: $e');
    }
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
      //key: webViewKey,
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
      shouldInterceptRequest: (controller, request) async {
        try {
          final requestUrl = request.url.toString();
          final requestHost = request.url.host.toLowerCase();

          // // Check general ad blocking (includes all major ad networks)
          // if (GeneralAdBlocker.shouldBlockRequest(
          //     requestUrl, requestHost)) {
          //   print('Blocked ad request: $requestHost');
          //   return WebResourceResponse(
          //     contentType: 'text/plain',
          //     data: Uint8List.fromList([]),
          //   );
          // }

          // YouTube-specific blocking
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
          // Handle external intents normally
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

          // If it's a normal web URL, open it in a new WebViewPage
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
