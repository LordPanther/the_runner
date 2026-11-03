import 'package:flutter/material.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/utils/translate.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder mark until real artwork exists: a runner in
            // a warm timber circle, no bundled asset needed.
            Container(
              width: SizeConfig.defaultSize * 9,
              height: SizeConfig.defaultSize * 9,
              decoration: const BoxDecoration(
                color: ColorConst.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_run_rounded,
                color: ColorConst.backgroundColor,
                size: SizeConfig.defaultSize * 5,
              ),
            ),
            SizedBox(height: SizeConfig.defaultPadding * 1.5),
            Text(
              'The Runner',
              style: FontConst.BOLD_DEFAULT_28,
            ),
            SizedBox(height: SizeConfig.defaultPadding * 0.4),
            Text(
              context.tr('tagline'),
              style: FontConst.REGULAR_SECONDARY_14,
            ),
            SizedBox(height: SizeConfig.defaultPadding * 2.5),
            SizedBox(
              width: SizeConfig.defaultSize * 2.4,
              height: SizeConfig.defaultSize * 2.4,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(ColorConst.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
