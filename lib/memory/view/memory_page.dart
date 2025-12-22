import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bavi/memory/bloc/memory_bloc.dart';
import 'package:bavi/memory/widgets/memory_card.dart';
import 'package:bavi/memory/widgets/empty_memory_view.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> with TickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    // Load chunks on init
    context.read<MemoryBloc>().add(MemoryLoadChunks());
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _onRefresh() {
    HapticFeedback.mediumImpact();
    context.read<MemoryBloc>().add(MemoryLoadChunks());
  }

  void _onClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Clear All Memories?',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will permanently delete all stored memory chunks. This action cannot be undone.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              context.read<MemoryBloc>().add(MemoryClearAll());
            },
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MemoryBloc, MemoryState>(
      listener: (context, state) {
        if (state.status == MemoryStatus.success) {
          _staggerController.forward(from: 0);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              // gradient: LinearGradient(
              //   begin: Alignment.topCenter,
              //   end: Alignment.bottomCenter,
              //   colors: [
              //     Colors.white,
              //     Color(0xFFF8F9FA),
              //     Color(0xFFF3F4F6),
              //   ],
              // ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Custom AppBar
                  _buildAppBar(state),

                  // Content
                  Expanded(
                    child: _buildContent(state),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(MemoryState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
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
                Icons.arrow_back_ios_new_rounded,
                color: Colors.grey.shade700,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Title and count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Memory',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 24,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (state.status == MemoryStatus.success)
                  Text(
                    '${state.chunks.length} memories stored',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          if (state.status == MemoryStatus.success && state.chunks.isNotEmpty)
            Row(
              children: [
                // Refresh button
                GestureDetector(
                  onTap: _onRefresh,
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
                      Icons.refresh_rounded,
                      color: Colors.grey.shade700,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear all button
                GestureDetector(
                  onTap: _onClearAll,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      color: const Color(0xFFEF4444).withOpacity(0.8),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent(MemoryState state) {
    switch (state.status) {
      case MemoryStatus.loading:
      case MemoryStatus.idle:
        return _buildLoadingShimmer();

      case MemoryStatus.empty:
        return const EmptyMemoryView();

      case MemoryStatus.failure:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load memories',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _onRefresh,
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Color(0xFF8A2BE2),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case MemoryStatus.success:
        return RefreshIndicator(
          onRefresh: () async {
            _onRefresh();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          color: const Color(0xFF8A2BE2),
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: state.chunks.length,
            itemBuilder: (context, index) {
              final chunk = state.chunks[index];

              // Staggered animation
              final delay = index * 0.1;
              final animation = Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(
                    delay.clamp(0.0, 1.0),
                    (delay + 0.4).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - animation.value)),
                    child: Opacity(
                      opacity: animation.value,
                      child: MemoryCard(
                        chunk: chunk,
                        index: index,
                        onDelete: () {
                          HapticFeedback.mediumImpact();
                          context
                              .read<MemoryBloc>()
                              .add(MemoryDeleteChunk(chunk.id));
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
    }
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 160,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey.shade100,
          ),
          child: _ShimmerLoading(delay: index * 100),
        );
      },
    );
  }
}

class _ShimmerLoading extends StatefulWidget {
  const _ShimmerLoading({required this.delay});

  final int delay;

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [
                Colors.grey.shade100,
                Colors.grey.shade200,
                Colors.grey.shade100,
              ],
            ),
          ),
        );
      },
    );
  }
}
