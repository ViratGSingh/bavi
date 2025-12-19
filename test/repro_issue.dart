import 'package:flutter_test/flutter_test.dart';
import 'package:bavi/home/bloc/home_bloc.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('HomeState copyWith should allow clearing selectedImage', () {
    final file = XFile('path/to/image');
    // Start with a state that has an image
    final state = HomeState(selectedImage: file);

    expect(state.selectedImage, isNotNull);

    // Attempt to clear it
    final newState = state.copyWith(selectedImage: null);

    expect(newState.selectedImage, isNull,
        reason:
            "selectedImage should be null after copyWith(selectedImage: null)");
  });
}
