import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
  InferenceModel? _activeModel;
  InferenceChat? _activeChat;

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

      // Initialize Gemma model
      await _initializeGemmaModel();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _initializeGemmaModel() async {
    try {
      final bool isEmulator = await _isEmulator();

      // Check if the 1B model is installed (this is what the download button installs)
      final is1BInstalled = await FlutterGemma.isModelInstalled(
          'Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.task');

      debugPrint('DEBUG Chat: 1B model installed: $is1BInstalled');

      if (is1BInstalled) {
        // Install/activate the 1B model - this sets it as the active model
        // Even if already installed, this "activates" it for use
        debugPrint('DEBUG Chat: Activating 1B model for chat...');
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
        )
            .fromNetwork(
              'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.task',
            )
            .install();
        debugPrint('DEBUG Chat: 1B model activated');
      } else {
        debugPrint(
            'DEBUG Chat: 1B model not installed, chat may not work properly');
        // Still try to use whatever is active
      }

      _activeModel = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend:
            isEmulator ? PreferredBackend.cpu : PreferredBackend.gpu,
      );

      _activeChat = await _activeModel?.createChat();
      debugPrint('DEBUG Chat: Gemma chat session created');
    } catch (e) {
      debugPrint('Error initializing Gemma model for chat: $e');
    }
  }

  Future<bool> _isEmulator() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }
    return false;
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
      // Initialize model if not already done
      if (_activeChat == null) {
        await _initializeGemmaModel();
      }

      if (_activeChat == null) {
        throw Exception(
            'Gemma model not available. Please ensure the model is downloaded.');
      }

      // Simple prompt - just the user query for the small model
      final prompt = event.query;
      debugPrint('DEBUG: Sending prompt to Gemma: $prompt');

      // Use Gemma for inference
      await _activeChat!.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));

      // Stream response token by token
      StringBuffer responseBuffer = StringBuffer();
      bool isComplete = false;
      int tokenCount = 0;
      const maxTokens = 500; // Safety limit

      debugPrint('DEBUG: Starting streaming response...');

      while (!isComplete && !_isCancelled && tokenCount < maxTokens) {
        final gemmaResponse = await _activeChat!.generateChatResponse();
        tokenCount++;

        if (gemmaResponse is TextResponse) {
          final token = gemmaResponse.token;

          // Check for end of response (empty token or special end markers)
          if (token.isEmpty) {
            isComplete = true;
            debugPrint(
                'DEBUG: Stream complete (empty token) after $tokenCount tokens');
          } else {
            responseBuffer.write(token);
            // Update the streamed text notifier for real-time UI updates
            event.streamedText.value = responseBuffer.toString();
          }
        } else {
          // Non-text response means we're done
          isComplete = true;
          debugPrint(
              'DEBUG: Stream complete (non-text response: ${gemmaResponse.runtimeType})');
        }
      }

      if (_isCancelled) {
        emit(state.copyWith(
          status: ChatPageStatus.idle,
          replyStatus: ChatReplyStatus.idle,
        ));
        return;
      }

      String response = responseBuffer.toString().trim();
      debugPrint('DEBUG: Final response length: ${response.length}');
      debugPrint('DEBUG: Final response: "$response"');

      // Only show fallback if response is truly empty
      if (response.isEmpty) {
        debugPrint('DEBUG: Response was empty, showing fallback');
        response =
            "I'm processing your request. The model returned an empty response - please try again.";
      }

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
        content:
            "I'm having trouble generating a response. Please make sure the AI model is downloaded.\n\nError: ${e.toString()}",
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

      // Reset chat session
      _activeChat = await _activeModel?.createChat();
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
