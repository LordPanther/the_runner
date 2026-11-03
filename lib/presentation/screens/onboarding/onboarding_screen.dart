import 'package:flutter/material.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/utils/translate.dart';

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
  });
}

// Titles and descriptions are translation keys (assets/locale/*.json).
// Keep every claim here true: Play rejects apps whose descriptions
// promise features they don't have, and users stop trusting them.
const _slides = [
  _OnboardingSlide(
    icon: Icons.add_task_rounded,
    title: 'onboarding_1_title',
    description: 'onboarding_1_body',
    iconColor: ColorConst.primaryColor,
  ),
  _OnboardingSlide(
    icon: Icons.directions_run_rounded,
    title: 'onboarding_2_title',
    description: 'onboarding_2_body',
    iconColor: ColorConst.secondaryColor,
  ),
  _OnboardingSlide(
    icon: Icons.verified_user_outlined,
    title: 'onboarding_3_title',
    description: 'onboarding_3_body',
    iconColor: ColorConst.accentColor,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  bool get _isLastSlide => _currentPage == _slides.length - 1;

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  void _onNextPressed() {
    if (_isLastSlide) {
      _goToLogin();
    } else {
      _controller.nextPage(
        duration: mAnimationDuration,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.defaultPadding),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    Translate.of(context).translate('onboarding_skip'),
                    style: FontConst.MEDIUM_SECONDARY_14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _SlideView(slide: _slides[index]),
              ),
            ),
            _PageIndicator(currentPage: _currentPage, count: _slides.length),
            SizedBox(height: SizeConfig.defaultPadding * 1.5),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.defaultPadding * 1.5,
              ),
              child: ElevatedButton(
                onPressed: _onNextPressed,
                child: Text(Translate.of(context).translate(
                  _isLastSlide ? 'onboarding_get_started' : 'onboarding_next',
                )),
              ),
            ),
            SizedBox(height: SizeConfig.defaultPadding * 1.5),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.defaultPadding * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: SizeConfig.defaultSize * 16,
            height: SizeConfig.defaultSize * 16,
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: SizeConfig.defaultSize * 7, color: slide.iconColor),
          ),
          SizedBox(height: SizeConfig.defaultPadding * 2),
          Text(
            Translate.of(context).translate(slide.title),
            textAlign: TextAlign.center,
            style: FontConst.BOLD_DEFAULT_24,
          ),
          SizedBox(height: SizeConfig.defaultPadding * 0.8),
          Text(
            Translate.of(context).translate(slide.description),
            textAlign: TextAlign.center,
            style: FontConst.REGULAR_SECONDARY_14,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int count;

  const _PageIndicator({required this.currentPage, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: mAnimationDuration,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? ColorConst.primaryColor : ColorConst.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}