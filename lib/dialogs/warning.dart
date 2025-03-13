import 'dart:ui';

import 'package:flutter/material.dart';

class WarningPopup extends StatelessWidget {
  final String title;
  final String message;
  final Color popupColor;
  final Function actionFunc;
  final String action;
  final String cancelText;
  final IconData popupIcon;
  final bool isInfo;
  const WarningPopup(
      {super.key,
      required this.title,
      required this.popupColor,
      required this.message,
      required this.action,
      required this.popupIcon,
      required this.actionFunc,
      this.isInfo = false,
      this.cancelText = "Close"});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
                color: Color(0xFF8A2BE2),
                // gradient: LinearGradient(
                //     begin: Alignment.topCenter,
                //     end: Alignment.bottomCenter,
                //     colors: [Color(0xFFFFB347), Color(0xFFF4900C)])
                    ),
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  popupIcon,
                  color: Colors.white,
                  size: 48,
                ),
              ],
            ),
          ),
          // Icon(
          //   Icons.error_outline,
          //   color: Colors.red,
          //   size: 64.0,
          // ),
          //SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 20),
                isInfo == true
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ButtonStyle(
                                // minimumSize: MaterialStateProperty.all(
                                //     Size(MediaQuery.of(context).size.width/4, 45)),
                                padding:
                                    MaterialStatePropertyAll(EdgeInsets.zero),
                                maximumSize: MaterialStateProperty.all(Size(
                                    MediaQuery.of(context).size.width, 45)),
                              ),
                              onPressed: () => actionFunc(),
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                height: 45,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFFFB347),
                                          Color(0xFFF4900C)
                                        ]),
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(-4, -4),
                                          spreadRadius: 0,
                                          blurRadius: 6,
                                          color: Color(0xFF8FBAE3)
                                              .withOpacity(0.2)),
                                      BoxShadow(
                                          offset: Offset(4, 4),
                                          spreadRadius: 0,
                                          blurRadius: 4,
                                          color: Color(0xFF052C52)
                                              .withOpacity(0.4))
                                    ],
                                    borderRadius: BorderRadius.circular(40)),
                                padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                                child: Center(
                                  child: Text(
                                    action,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ButtonStyle(
                                // minimumSize: MaterialStateProperty.all(
                                //     Size(MediaQuery.of(context).size.width/4, 45)),
                                padding:
                                    MaterialStatePropertyAll(EdgeInsets.zero),
                                maximumSize: MaterialStateProperty.all(Size(
                                    MediaQuery.of(context).size.width / 3, 42)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                width: MediaQuery.of(context).size.width / 3,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF3EAFC),
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(-4, -4),
                                          spreadRadius: 0,
                                          blurRadius: 6,
                                          color: Color(0xFF8FBAE3)
                                              .withOpacity(0.2)),
                                      BoxShadow(
                                          offset: Offset(4, 4),
                                          spreadRadius: 0,
                                          blurRadius: 4,
                                          color: Color(0xFF052C52)
                                              .withOpacity(0.4))
                                    ],
                                    borderRadius: BorderRadius.circular(40)),
                                child: Center(
                                  child: Text(
                                    cancelText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Color(0xFF8A2BE2),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ButtonStyle(
                                // minimumSize: MaterialStateProperty.all(
                                //     Size(MediaQuery.of(context).size.width/4, 45)),
                                padding:
                                    MaterialStatePropertyAll(EdgeInsets.zero),
                                maximumSize: MaterialStateProperty.all(Size(
                                    MediaQuery.of(context).size.width / 3, 42)),
                              ),
                              onPressed: () => actionFunc(),
                              child: Container(
                                width: MediaQuery.of(context).size.width / 3,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: Color(0xFF8A2BE2),
                                    boxShadow: [
                                      BoxShadow(
                                          offset: Offset(-4, -4),
                                          spreadRadius: 0,
                                          blurRadius: 6,
                                          color: Color(0xFF8FBAE3)
                                              .withOpacity(0.2)),
                                      BoxShadow(
                                          offset: Offset(4, 4),
                                          spreadRadius: 0,
                                          blurRadius: 4,
                                          color: Color(0xFF052C52)
                                              .withOpacity(0.4))
                                    ],
                                    borderRadius: BorderRadius.circular(40)),
                                child: Center(
                                  child: Text(
                                    action,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),

      //actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}
