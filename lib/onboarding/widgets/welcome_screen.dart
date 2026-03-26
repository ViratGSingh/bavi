import 'package:bavi/home/view/home_page.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onNext;
  const WelcomeScreen({super.key, required this.onNext});

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
                  translation: const Offset(0, 0.15),
                  child: Image.asset(
                        'assets/images/onboarding/welcome.jpeg',
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
          flex: 20,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(children: [
                   const Text(
                  'Curiosity Without Compromise',//\nthrough the web',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A private assistant that chats, sees\nand browses the web for you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
               
                ],),

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
                      "Let's Start!",
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
