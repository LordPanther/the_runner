// lib/presentation/screens/errands/my_errands_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/friendly_error.dart';
import 'package:the_runner/core/widgets/errand_card.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/utils/translate.dart';

/// Two lists in one tab: errands you posted, and errands you're running.
/// Each list gets its OWN ErrandBloc so loading one never overwrites the
/// other (the same reason Town Post scoped JobBloc per screen).
class MyErrandsScreen extends StatelessWidget {
  const MyErrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ColorConst.backgroundColor,
        appBar: AppBar(
          title: Text(context.tr('my_errands')),
          bottom: TabBar(
            labelColor: ColorConst.primaryColor,
            unselectedLabelColor: ColorConst.textSecondaryColor,
            indicatorColor: ColorConst.primaryColor,
            tabs: [
              Tab(text: context.tr('tab_posted')),
              Tab(text: context.tr('tab_running')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BlocProvider(
              create: (_) => ErrandBloc(),
              child: const _ErrandList(posted: true),
            ),
            BlocProvider(
              create: (_) => ErrandBloc(),
              child: const _ErrandList(posted: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrandList extends StatefulWidget {
  /// True: errands I posted. False: errands I'm the runner on.
  final bool posted;

  const _ErrandList({required this.posted});

  @override
  State<_ErrandList> createState() => _ErrandListState();
}

class _ErrandListState extends State<_ErrandList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    context.read<ErrandBloc>().add(widget.posted ? LoadMyPostedErrands(uid) : LoadMyRuns(uid));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<ErrandBloc, ErrandState>(
      builder: (context, state) {
        if (state is ErrandLoading || state is ErrandInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ErrandError) {
          return Center(child: Text(context.errorText(state.message)));
        }
        final errands = state is ErrandsListLoaded ? state.errands : <ErrandModel>[];
        if (errands.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.defaultPadding * 2),
              child: Text(
                context.tr(widget.posted ? 'no_posted_errands' : 'no_runs_yet'),
                textAlign: TextAlign.center,
                style: FontConst.REGULAR_SECONDARY_14,
              ),
            ),
          );
        }

        // Anything that still needs someone to act goes on top.
        final active = errands.where((e) => !e.status.isFinished).toList();
        final finished = errands.where((e) => e.status.isFinished).toList();

        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: EdgeInsets.all(SizeConfig.defaultPadding),
            children: [
              for (final errand in [...active, ...finished])
                Padding(
                  padding: EdgeInsets.only(bottom: SizeConfig.defaultPadding * 0.5),
                  child: ErrandCard(
                    errand: errand,
                    onTap: () async {
                      await Navigator.of(context).pushNamed(
                        AppRouter.errandDetail,
                        arguments: errand.id,
                      );
                      if (mounted) _load();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
