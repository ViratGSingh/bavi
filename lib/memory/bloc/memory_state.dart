part of 'memory_bloc.dart';

enum MemoryStatus { idle, loading, success, failure, empty }

final class MemoryState extends Equatable {
  const MemoryState({
    this.status = MemoryStatus.idle,
    this.chunks = const [],
    this.errorMessage = '',
  });

  final MemoryStatus status;
  final List<AnswerChunk> chunks;
  final String errorMessage;

  MemoryState copyWith({
    MemoryStatus? status,
    List<AnswerChunk>? chunks,
    String? errorMessage,
  }) {
    return MemoryState(
      status: status ?? this.status,
      chunks: chunks ?? this.chunks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, chunks, errorMessage];
}
