import 'dart:io';
import 'dart:typed_data';
import 'package:bavi/home/widgets/web_view.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:bavi/app_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bavi/tables/tabs.dart';
import 'package:uuid/uuid.dart';

class TabsViewPage extends StatefulWidget {
  const TabsViewPage({super.key});

  @override
  State<TabsViewPage> createState() => _TabsViewPageState();
}

class _TabsViewPageState extends State<TabsViewPage> {
  late AppDatabase db;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<Tab> _tabsFromDb = [];
  bool isGridView = true; // Toggle between tab grid and actual browser
  List<Map<String, dynamic>> tabs = [];
  int activeTabIndex = 0;

  @override
  void initState() {
    db = AppDatabase();
    super.initState();
    _loadTabs();
    //_addNewTab(initialUrl: widget.url, title: widget.title ?? "New Tab");
  }

  Future<void> _loadTabs() async {
    final tabs = await db.getAllTabs();
    tabs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _tabsFromDb = tabs;
    });
  }

  void _addNewTab({String? initialUrl, String? title}) {
    final newTab = {
      'id': const Uuid().v4(),
      'title': title ?? 'New Tab',
      'url': initialUrl ?? 'https://www.google.com',
      'imagePath': null,
    };
    setState(() {
      tabs.add(newTab);
      activeTabIndex = tabs.length - 1;
      isGridView = false;
    });
  }

  void _closeTab(int index) {
    setState(() {
      tabs.removeAt(index);
      if (activeTabIndex >= tabs.length) {
        activeTabIndex = tabs.isNotEmpty ? tabs.length - 1 : 0;
      }
      if (tabs.isEmpty) isGridView = true;
    });
  }

  Future<void> _deleteAllTabs() async {
    for (final tab in _tabsFromDb) {
      await db.deleteTab(tab.id);
    }
    setState(() {
      _tabsFromDb.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = tabs.isNotEmpty ? tabs[activeTabIndex] : null;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
          leadingWidth: 40,
          centerTitle: true,
          //state.status == HomePageStatus.idle ? true : false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 0),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  //color: Color(0xFFDFFF00),
                  shape: BoxShape.circle,
                  //border: Border.all()
                ),
                padding: EdgeInsets.fromLTRB(1, 0, 2, 0),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          title: Text(
            'Tabs',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  // String? currentUrl = widget.url;
                  // if (currentUrl != "") {
                  //   Share.share(currentUrl);
                  // } else {
                  //   ScaffoldMessenger.of(context).showSnackBar(
                  //     const SnackBar(
                  //       content: Text('Unable to share link'),
                  //       duration: Duration(seconds: 2),
                  //     ),
                  //   );
                  // }
                  _deleteAllTabs();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      // borderRadius: BorderRadius.circular(18),
                      // color: Color(0xFFDFFF00),
                      // border: Border.all()
                      ),
                  child: Center(
                    child: Icon(
                      Iconsax.broom_outline,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        body: _tabsFromDb.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tab_outlined,
                        size: 70, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No open tabs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Open a new tab to start browsing',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : _buildTabsGridView(),
      ),
    );
  }

  Widget _buildTabsGridView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        itemCount: _tabsFromDb.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final tab = _tabsFromDb[index];
          return _buildTabCard(tab, index);
        },
      ),
    );
  }

  final Map<String, bool> _deletingTabs = {};

  Widget _buildTabCard(Tab tab, int index) {
    final isDeleting = _deletingTabs[tab.id] ?? false;

    return AnimatedScale(
      scale: isDeleting ? 0.8 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isDeleting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: AspectRatio(
          aspectRatio: 0.7,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFF8A2BE2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tab.title ?? 'New Tab',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _deleteTabWithAnimation(index, tab),
                        child: const CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.transparent,
                          child:
                              Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => WebViewPage(
                            url: tab.url,
                            title: tab.title,
                            tabId: tab.id,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF8A2BE2), width: 3),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                        color: Colors.grey[200],
                      ),
                      child: tab.imagePath == null
                          ? const Center(child: Icon(Icons.language, size: 40))
                          : ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              child: Image.file(
                                File(tab.imagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTabWithAnimation(int index, Tab tab) async {
    // Mark tab as deleting to trigger animation
    setState(() {
      _deletingTabs[tab.id] = true;
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 250));

    // Remove from list and clean up
    setState(() {
      _tabsFromDb.removeAt(index);
      _deletingTabs.remove(tab.id);
    });

    // Delete from database
    await db.deleteTab(tab.id);
  }

  Widget _buildTabTile(Tab tab, int index) {
    return AspectRatio(
      aspectRatio: 0.7,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF8A2BE2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tab.title ?? 'New Tab',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeTab(index, tab),
                    child: const CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => WebViewPage(
                        url: tab.url,
                        title: tab.title,
                        tabId: tab.id,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFF8A2BE2), width: 3),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    color: Colors.grey[200],
                  ),
                  child: tab.imagePath == null
                      ? const Center(child: Icon(Icons.language, size: 40))
                      : ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          child: Image.file(
                            File(tab.imagePath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeTab(int index, Tab tab) {
    final removedTab = _tabsFromDb[index];
    _tabsFromDb.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => ScaleTransition(
        scale: animation,
        child: _buildTabTile(removedTab, index),
      ),
      duration: const Duration(milliseconds: 300),
    );
    Future.delayed(const Duration(milliseconds: 300), () async {
      await db.deleteTab(tab.id);
    });
    setState(() {});
  }

  Widget _buildBrowserView(Map<String, dynamic> tab) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(tab['url'])),
          onWebViewCreated: (controller) async {
            controller.addJavaScriptHandler(
              handlerName: 'titleChanged',
              callback: (args) async {
                setState(() {
                  tab['title'] = args.first.toString();
                });
              },
            );
          },
          onLoadStop: (controller, url) async {
            final title = await controller.getTitle();
            setState(() => tab['title'] = title ?? 'New Tab');
            await _saveScreenshot(controller, tab);
          },
        ),
      ],
    );
  }

  Future<void> _saveScreenshot(
      InAppWebViewController controller, Map<String, dynamic> tab) async {
    try {
      final screenshot = await controller.takeScreenshot();
      if (screenshot == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/${tab['id']}.png");
      await file.writeAsBytes(screenshot);

      setState(() {
        tab['imagePath'] = file.path;
      });
    } catch (e) {
      debugPrint("Screenshot failed: $e");
    }
  }
}
