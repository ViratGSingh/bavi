import 'package:bavi/navigation_service.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  final String name;
  const WelcomePage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    TextEditingController _textController = TextEditingController();
    _textController.text = "https://www.instagram.com/reel/DE2XfdvS5ld";
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello $name!",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    "Here's the link to your first video",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(width: 1, color: Color(0xFF090E1D)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0xFF080E1D),
                          blurRadius: 0,
                          offset: Offset(0, 4),
                          spreadRadius: 0,
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            readOnly: true,
                            onChanged: (value) {
                              // setState(() {});
                              // context.read<AddVideoBloc>().add(
                              //       AddVideoCheckLink(value),
                              //     );
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter link',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "To include a short video in your library, simply copy its link from the platform and paste it here.",
                    style: TextStyle(
                      color: Color(0xFF5A5E68),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                               onPressed:   () {
                                       navService.goTo("/addVideo", queryParams: {"isOnboarding":"true"});
                                      },
                                style: ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                      _textController.text == ""
                                          ? Color(0xFFF3EAFC)
                                          : Color(0xFF8A2BE2),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        side: BorderSide(
                                            width: 1, color: Colors.white),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    fixedSize: WidgetStatePropertyAll(
                                      Size(MediaQuery.of(context).size.width,
                                          56),
                                    )),
                                child: Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: _textController.text == ""
                                        ? Color(0xFFC99DF2)
                                        : Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
            ],
          ),
        ),
      ),
    );
  }
}
