part of 'memory_bloc.dart';

@immutable
sealed class MemoryEvent {}

/// Load all memory chunks from ObjectBox
final class MemoryLoadChunks extends MemoryEvent {}

/// Delete a specific memory chunk by ID
final class MemoryDeleteChunk extends MemoryEvent {
  final int chunkId;
  MemoryDeleteChunk(this.chunkId);
}

/// Clear all stored memories
final class MemoryClearAll extends MemoryEvent {}
