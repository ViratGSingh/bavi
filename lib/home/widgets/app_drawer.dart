import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:bavi/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

/// Full-screen history page that displays thread history with search functionality.
/// Replaces the previous drawer-based approach.
class HistoryPage extends StatefulWidget {
  final List<ThreadSessionData> sessions;
  final Function(ThreadSessionData session) onSessionTap;
  final VoidCallback? onNewThread;
  final HomeHistoryStatus historyStatus;

  const HistoryPage({
    super.key,
    required this.sessions,
    required this.historyStatus,
    required this.onSessionTap,
    this.onNewThread,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  bool _isSearchFocused = false;

  List<ThreadSessionData> get filteredSessions {
    if (_searchQuery.isEmpty) {
      return widget.sessions;
    }
    final searchLower = _searchQuery.toLowerCase();
    return widget.sessions.where((session) {
      // Search in title and summary
      if (session.title.toLowerCase().contains(searchLower)) return true;
      if (session.summary.toLowerCase().contains(searchLower)) return true;

      // Search in all queries and answers in the thread
      for (final result in session.results) {
        if (result.userQuery.toLowerCase().contains(searchLower)) return true;
        if (result.answer.toLowerCase().contains(searchLower)) return true;
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _widthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
    if (_searchFocusNode.hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onSearchSubmitted(String value) {
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, child) {
          // Animate from 85% to 100% width
          final panelWidth =
              screenWidth * (0.85 + (0.15 * _widthAnimation.value));
          // Animate border radius from 16 to 0
          final borderRadius = 16.0 * (1 - _widthAnimation.value);

          return Row(
            children: [
              // History panel - animates from 85% to full width
              Container(
                width: panelWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(borderRadius),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // // App Bar
                      // _buildAppBar(),
                      // Search Bar
                      _buildSearchBar(),
                      // Content
                      Expanded(
                        child: _buildContent(),
                      ),
                    ],
                  ),
                ),
              ),
              // Tap to close area - shrinks as panel expands
              if (_widthAnimation.value < 1.0)
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      color: Colors.black
                          .withOpacity(0.3 * (1 - _widthAnimation.value)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // // Back button
          // IconButton(
          //   onPressed: () => Navigator.pop(context),
          //   icon: Icon(
          //     Icons.arrow_back_ios_new_rounded,
          //     color: Colors.grey.shade800,
          //     size: 20,
          //   ),
          //   splashRadius: 24,
          // ),
          const SizedBox(width: 8),
          // Title
          const Expanded(
            child: Text(
              'History',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Forward arrow (optional navigation hint)
          // IconButton(
          //   onPressed: () => Navigator.pop(context),
          //   icon: Icon(
          //     Icons.arrow_forward_ios_rounded,
          //     color: Colors.grey.shade800,
          //     size: 20,
          //   ),
          //   splashRadius: 24,
          // ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade700,
                size: 20,
              ),
            ),
          ),
          SizedBox(
            width: 8,
          )
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: _isSearchFocused
                    ? Border.all(color: Colors.grey.shade400, width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.search,
                      color: _isSearchFocused
                          ? Colors.grey.shade700
                          : Colors.grey.shade500,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 18,
                  ),
                  suffixIcon: (_searchQuery.isNotEmpty || _isSearchFocused)
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _searchFocusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          // Edit/New Thread button
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onNewThread != null) {
                widget.onNewThread!();
              }
              Navigator.pop(context);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.edit_outline,
                color: Colors.grey.shade700,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.historyStatus == HomeHistoryStatus.loading) {
      return _buildLoadingShimmer();
    }

    final sessions = filteredSessions;

    if (sessions.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No threads found',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontFamily: 'Poppins',
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.white,
      ),
      itemBuilder: (context, index) {
        final data = sessions[index];
        return _buildThreadItem(data);
      },
    );
  }

  Widget _buildThreadItem(ThreadSessionData data) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSessionTap(data);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thread title - prefer title if available, otherwise use first query
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    data.title.isNotEmpty
                        ? data.title
                        : (data.results.isNotEmpty
                            ? data.results.first.userQuery
                            : "New Thread"),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // More options button
                // Icon(
                //   Icons.more_horiz,
                //   color: Colors.grey.shade400,
                //   size: 20,
                // ),
              ],
            ),
            // Thread preview - prefer summary if available, otherwise use first answer
            if (_hasPreviewContent(data))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  data.summary.isNotEmpty
                      ? data.summary
                      : data.results.first.answer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            // Metadata row
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.clock_outline,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(data.createdAt.toDate()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Iconsax.link_2_outline,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${data.results.length}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns true if the thread has preview content to display
  bool _hasPreviewContent(ThreadSessionData data) {
    if (data.summary.isNotEmpty) return true;
    if (data.results.isNotEmpty && data.results.first.answer.isNotEmpty) {
      return true;
    }
    return false;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat("MMM d").format(dateTime);
    }
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (index != 5) Divider(height: 1, color: Colors.grey.shade200),
          ],
        );
      },
    );
  }
}

/// Slide from left page route for the history page transition.
class SlideFromLeftRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFromLeftRoute({required this.page})
      : super(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

/// Slide from right page route for pages that should slide in from the right edge.
class SlideFromRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFromRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Start from right edge
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

// Keep the old ChatAppDrawer for backwards compatibility, but mark as deprecated
@Deprecated('Use HistoryPage instead with Navigator.push')
class ChatAppDrawer extends StatelessWidget {
  final List<ThreadSessionData> sessions;
  final Function(ThreadSessionData session) onSessionTap;
  final HomeHistoryStatus historyStatus;

  const ChatAppDrawer({
    super.key,
    required this.sessions,
    required this.historyStatus,
    required this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to HistoryPage behavior
    return HistoryPage(
      sessions: sessions,
      historyStatus: historyStatus,
      onSessionTap: onSessionTap,
    );
  }
}
