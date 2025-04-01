import 'package:bavi/dialogs/warning.dart';
import 'package:bavi/login/bloc/login_bloc.dart';
import 'package:bavi/settings/bloc/settings_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    initMixpanel();
    context.read<SettingsBloc>().add(SettingsInitiateMixpanel());
  }

  late Mixpanel mixpanel;
  Future<void> initMixpanel() async {
    // initialize Mixpanel
     mixpanel = await Mixpanel.init(dotenv.get("MIXPANEL_PROJECT_KEY"),
        trackAutomaticEvents: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(builder: (context, state) {
      return SafeArea(
        child: Scaffold(
            backgroundColor: Colors.white,
            appBar:  state.status == SettingsStatus.logout ||
                      state.status == SettingsStatus.delete
                  ? null
                  :AppBar(
              elevation: 1,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shadowColor: Colors.black,
              leadingWidth: 70,
              leading: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(),
                  child: Icon(Icons.arrow_back_ios, color: Colors.black),
                ),
              ),
              title: Text(
                'Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF090E1D),
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              //automaticallyImplyLeading: false,
              centerTitle: true,
            ),
            body: Padding(
              padding: EdgeInsets.only( bottom: 20),
              child: state.status == SettingsStatus.logout ||
                      state.status == SettingsStatus.delete
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              value: null,
                              color: Color(0xFF8A2BE2),
                            ),
                          ),
                          SizedBox(height: 15),
                          Text(
                            state.status == SettingsStatus.logout
                                ?
                                //Logout progress
                                "Logging Out"
                                :
                                //Delete progress
                                "Deleting Account",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        InkWell(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) => WarningPopup(
                                      title: "Logout",
                                      message:
                                          "Are you sure you want to logout?",
                                      action: "Yes",
                                      popupColor: Color(0xFF8A2BE2),
                                      isInfo: false,
                                      popupIcon: Icons.info,
                                      actionFunc: () {
                                        Navigator.pop(context);
                                        mixpanel.track("sign_out");
                                        context
                                            .read<SettingsBloc>()
                                            .add(SettingsLogout());
                                      },
                                      cancelText: "No",
                                    ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Iconsax.logout_bold,
                                    color: Colors.black, size: 24),
                                    SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text(
                                  "Logout",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 5),
                                   Container(
                                    width: MediaQuery.of(context).size.width- 80,
                                     child: Text(
                                                                     "Logout from your account to create/login another account of yours",
                                                                 style: TextStyle(
                                                                   color: Colors.black,
                                                                   fontSize: 14,
                                                                   fontFamily: 'Poppins',
                                                                   fontWeight: FontWeight.w400,
                                                                 ),
                                                               ),
                                   ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                           InkWell(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) => WarningPopup(
                                      title: "Delete",
                                      message:
                                          "Are you sure you want to delete your account?",
                                      action: "Yes",
                                      popupColor: Color(0xFF8A2BE2),
                                      isInfo: false,
                                      popupIcon: Icons.info,
                                      actionFunc: () {
                                        Navigator.pop(context);
                                        mixpanel.track("delete_account");
                                        context
                                            .read<SettingsBloc>()
                                            .add(SettingsDelete());
                                      },
                                      cancelText: "No",
                                    ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Iconsax.profile_delete_bold,
                                    color: Color(0xFFD80004), size: 24),
                                SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text(
                                  "Delete",
                              style: TextStyle(
                                color: Color(0xFFD80004),
                                fontSize: 18,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 5),
                                   Container(
                                    width: MediaQuery.of(context).size.width- 80,
                                     child: Text(
                                                                     "Delete your account data and videos stored in your library",
                                                                 style: TextStyle(
                                                                   color: Color(0xFFD80004),
                                                                   fontSize: 14,
                                                                   fontFamily: 'Poppins',
                                                                   fontWeight: FontWeight.w400,
                                                                 ),
                                                               ),
                                   ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
            )),
      );
    });
  }
}
