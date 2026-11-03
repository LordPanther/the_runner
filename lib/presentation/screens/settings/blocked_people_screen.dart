// lib/presentation/screens/settings/blocked_people_screen.dart

import 'package:flutter/material.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/data/repositories/app_repository.dart';
import 'package:the_runner/data/services/block_list.dart';
import 'package:the_runner/utils/translate.dart';

/// Settings -> Blocked people: everyone this user has blocked, with an
/// Unblock button each.
class BlockedPeopleScreen extends StatelessWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translate.of(context);
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      appBar: AppBar(title: Text(t.translate('blocked_people_title'))),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: BlockList.instance.blocked,
        builder: (context, blocked, _) {
          if (blocked.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(SizeConfig.defaultPadding * 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: 48, color: ColorConst.textSecondaryColor),
                    SizedBox(height: SizeConfig.defaultPadding),
                    Text(
                      t.translate('blocked_people_empty'),
                      textAlign: TextAlign.center,
                      style: FontConst.REGULAR_SECONDARY_14,
                    ),
                  ],
                ),
              ),
            );
          }

          final uids = blocked.toList();
          return ListView.separated(
            padding: EdgeInsets.all(SizeConfig.defaultPadding),
            itemCount: uids.length,
            separatorBuilder: (_, _) => Divider(color: ColorConst.dividerColor),
            itemBuilder: (context, index) => _BlockedPersonTile(uid: uids[index]),
          );
        },
      ),
    );
  }
}

class _BlockedPersonTile extends StatefulWidget {
  final String uid;

  const _BlockedPersonTile({required this.uid});

  @override
  State<_BlockedPersonTile> createState() => _BlockedPersonTileState();
}

class _BlockedPersonTileState extends State<_BlockedPersonTile> {
  // Name and photo for display. The account may have been deleted, in
  // which case it shows as "The Runner user".
  late final Future<({String name, String? photoUrl})> _person = _load();
  bool _busy = false;

  Future<({String name, String? photoUrl})> _load() async {
    try {
      final user = await AppRepository.authRepository.getUserById(widget.uid);
      final name = (user?.displayName ?? '').trim();
      return (name: name, photoUrl: user?.photoUrl);
    } catch (_) {
      return (name: '', photoUrl: null);
    }
  }

  Future<void> _unblock() async {
    final t = Translate.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await BlockList.instance.unblock(widget.uid);
      messenger.showSnackBar(SnackBar(content: Text(t.translate('unblocked_done'))));
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text(t.translate('action_failed_try_again')),
        backgroundColor: ColorConst.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translate.of(context);
    return FutureBuilder<({String name, String? photoUrl})>(
      future: _person,
      builder: (context, snapshot) {
        final person = snapshot.data;
        final name = (person?.name.isNotEmpty ?? false)
            ? person!.name
            : t.translate('runner_user');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: ColorConst.primaryColor.withValues(alpha: 0.12),
            backgroundImage:
                person?.photoUrl != null ? NetworkImage(person!.photoUrl!) : null,
            child: person?.photoUrl == null
                ? Icon(Icons.person_rounded, color: ColorConst.primaryColor)
                : null,
          ),
          title: Text(name, style: FontConst.MEDIUM_DEFAULT_16),
          trailing: TextButton(
            onPressed: _busy ? null : _unblock,
            child: Text(t.translate('unblock_action')),
          ),
        );
      },
    );
  }
}
