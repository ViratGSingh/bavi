import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:bavi/models/answer_chunk.dart';
import 'package:bavi/objectbox_store.dart';

part 'memory_event.dart';
part 'memory_state.dart';

class MemoryBloc extends Bloc<MemoryEvent, MemoryState> {
  MemoryBloc() : super(const MemoryState()) {
    on<MemoryLoadChunks>(_onLoadChunks);
    on<MemoryDeleteChunk>(_onDeleteChunk);
    on<MemoryClearAll>(_onClearAll);
  }

  Future<void> _onLoadChunks(
    MemoryLoadChunks event,
    Emitter<MemoryState> emit,
  ) async {
    emit(state.copyWith(status: MemoryStatus.loading));

    try {
      // Initialize ObjectBox first
      final objectBox = await ObjectBoxStore.initialize();
      if (objectBox == null || objectBox.store == null) {
        emit(state.copyWith(
          status: MemoryStatus.failure,
          errorMessage: 'ObjectBox store not available',
        ));
        return;
      }

      final box = objectBox.store!.box<AnswerChunk>();
      final allChunks = box.getAll();

      // Sort by lastUsedAt descending (most recent first)
      allChunks.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

      if (allChunks.isEmpty) {
        emit(state.copyWith(status: MemoryStatus.empty, chunks: []));
      } else {
        emit(state.copyWith(status: MemoryStatus.success, chunks: allChunks));
      }

      debugPrint('📚 Loaded ${allChunks.length} memory chunks');
    } catch (e) {
      debugPrint('❌ Error loading memory chunks: $e');
      emit(state.copyWith(
        status: MemoryStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteChunk(
    MemoryDeleteChunk event,
    Emitter<MemoryState> emit,
  ) async {
    try {
      final objectBox = ObjectBoxStore.instanceOrNull;
      if (objectBox == null || objectBox.store == null) return;

      final box = objectBox.store!.box<AnswerChunk>();
      box.remove(event.chunkId);

      // Refresh the list
      final updatedChunks =
          state.chunks.where((c) => c.id != event.chunkId).toList();

      if (updatedChunks.isEmpty) {
        emit(state.copyWith(status: MemoryStatus.empty, chunks: []));
      } else {
        emit(state.copyWith(chunks: updatedChunks));
      }

      debugPrint('🗑️ Deleted memory chunk ${event.chunkId}');
    } catch (e) {
      debugPrint('❌ Error deleting memory chunk: $e');
    }
  }

  Future<void> _onClearAll(
    MemoryClearAll event,
    Emitter<MemoryState> emit,
  ) async {
    try {
      final objectBox = ObjectBoxStore.instanceOrNull;
      if (objectBox == null || objectBox.store == null) return;

      final box = objectBox.store!.box<AnswerChunk>();
      box.removeAll();

      emit(state.copyWith(status: MemoryStatus.empty, chunks: []));

      debugPrint('🧹 Cleared all memory chunks');
    } catch (e) {
      debugPrint('❌ Error clearing memory chunks: $e');
    }
  }
}
