import 'package:bavi/home/view/home_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SetupScreen extends StatelessWidget {
  final VoidCallback onNext;
  const SetupScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top section with lavender background and Lottie animation
        Expanded(
          flex: 55,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFf3eafc),
                ),
                clipBehavior: Clip.hardEdge,
                alignment: Alignment.topCenter,
                child: FractionalTranslation(
                  translation: const Offset(0, 0.2),
                  child: Image.asset(
                        'assets/images/onboarding/setup.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                ),
              ),

                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(50.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // D with chat icon inside
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Text(
                              'D',
                              style: TextStyle(
                                color: Color(0xFF8A2BE2),
                                fontSize: 56,
                                fontFamily: 'BagelFatOne',
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            Container(
                              color: Color(0xFF8A2BE2),
                              width: 20,
                              height: 30,
                              child: SizedBox.shrink(),
                            ),
                            // Yellow chat bubble icon positioned inside D's counter
                            Positioned(
                              top: 24,
                              left: 14,
                              child: CustomPaint(
                                size: Size(10, 18),
                                painter: ChatBubblePainter(
                                  color: Color(0xFFDFFF00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // rissy text
                        Text(
                          'rissy',
                          style: TextStyle(
                            color: Color(0xFF8A2BE2),
                            fontSize: 56,
                            fontFamily: 'BagelFatOne',
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Bottom white card section
        Expanded(
          flex: 25,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            transform: Matrix4.translationValues(0, -28, 0),
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: Column(
              children: [

                const Text(
                  'Setup Your Personal Assistant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We’ll show you how to set up your very own assistant that lives entirely on your hardware',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // "Let's Start!" button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8A2BE2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
