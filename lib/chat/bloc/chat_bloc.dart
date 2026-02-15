import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(const ChatState()) {
    on<ChatSendMessage>(_onSendMessage);
    on<ChatClearHistory>(_onClearHistory);
    on<ChatStartNewSession>(_onStartNewSession);
    on<ChatImageSelected>(_onImageSelected);
    on<ChatImageUnselected>(_onImageUnselected);
    on<ChatCancelResponse>(_onCancelResponse);
    on<ChatLoadHistory>(_onLoadHistory);
  }

  static const String _chatHistoryKey = 'offline_chat_history';
  bool _isCancelled = false;

  Future<void> _onLoadHistory(
    ChatLoadHistory event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_chatHistoryKey);

      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        final messages = decoded
            .map((m) => ChatMessage(
                  content: m['content'] as String,
                  isUser: m['isUser'] as bool,
                  timestamp: m['timestamp'] != null
                      ? DateTime.parse(m['timestamp'] as String)
                      : null,
                ))
            .toList();

        emit(state.copyWith(messages: messages));
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> historyData = messages
          .map((m) => <String, dynamic>{
                'content': m.content,
                'isUser': m.isUser,
                'timestamp': m.timestamp?.toIso8601String(),
              })
          .toList();
      final historyJson = jsonEncode(historyData);
      await prefs.setString(_chatHistoryKey, historyJson);
      debugPrint('DEBUG: Saved chat history with ${messages.length} messages');
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (event.query.trim().isEmpty) return;

    _isCancelled = false;

    // Add user message to the list
    final userMessage = ChatMessage(
      content: event.query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMessage];

    emit(state.copyWith(
      status: ChatPageStatus.loading,
      replyStatus: ChatReplyStatus.loading,
      messages: updatedMessages,
      currentQuery: event.query,
    ));

    // Save user message immediately
    await _saveHistory(updatedMessages);

    try {
      if (_isCancelled) {
        emit(state.copyWith(
          status: ChatPageStatus.idle,
          replyStatus: ChatReplyStatus.idle,
        ));
        return;
      }

      const response =
          "Local AI chat is currently unavailable. Please use the main search feature instead.";

      event.streamedText.value = response;

      final aiMessage = ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      final finalMessages = [...updatedMessages, aiMessage];

      emit(state.copyWith(
        status: ChatPageStatus.success,
        replyStatus: ChatReplyStatus.success,
        messages: finalMessages,
      ));

      // Save complete conversation
      await _saveHistory(finalMessages);
    } catch (e) {
      debugPrint('Error generating response: $e');

      final errorMessage = ChatMessage(
        content: "I'm having trouble generating a response.\n\nError: ${e.toString()}",
        isUser: false,
        timestamp: DateTime.now(),
      );

      final messagesWithError = [...updatedMessages, errorMessage];

      emit(state.copyWith(
        status: ChatPageStatus.failure,
        replyStatus: ChatReplyStatus.failure,
        messages: messagesWithError,
      ));

      await _saveHistory(messagesWithError);
    }
  }

  Future<void> _onClearHistory(
    ChatClearHistory event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(
      messages: [],
      status: ChatPageStatus.idle,
      replyStatus: ChatReplyStatus.idle,
    ));

    // Clear from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  void _onStartNewSession(
    ChatStartNewSession event,
    Emitter<ChatState> emit,
  ) {
    emit(const ChatState());
  }

  Future<void> _onImageSelected(
    ChatImageSelected event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(
      selectedImage: event.image,
      imageStatus: ChatImageStatus.selected,
      isAnalyzingImage: true,
    ));

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      emit(state.copyWith(isAnalyzingImage: false));
    } catch (e) {
      emit(state.copyWith(isAnalyzingImage: false));
    }
  }

  void _onImageUnselected(
    ChatImageUnselected event,
    Emitter<ChatState> emit,
  ) {
    event.imageDescription.value = '';
    emit(state.copyWith(
      selectedImage: null,
      imageStatus: ChatImageStatus.unselected,
      isAnalyzingImage: false,
    ));
  }

  void _onCancelResponse(
    ChatCancelResponse event,
    Emitter<ChatState> emit,
  ) {
    _isCancelled = true;
    emit(state.copyWith(
      status: ChatPageStatus.idle,
      replyStatus: ChatReplyStatus.idle,
    ));
  }
}
