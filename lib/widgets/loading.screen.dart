import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
            ),
            child: Image.asset(
              "assets/images/home/bavi_icon.png",
              fit: BoxFit.cover,
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
            ),
            child: CircularProgressIndicator(
              color: Color(0xFFDFFF00),
            ),
          ),
        ],
      ),
    ));
  }
}
