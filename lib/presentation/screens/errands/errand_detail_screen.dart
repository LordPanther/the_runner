// lib/presentation/screens/errands/errand_detail_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/fees.dart';
import 'package:the_runner/core/utils/friendly_error.dart';
import 'package:the_runner/core/utils/labels.dart';
import 'package:the_runner/core/widgets/errand_card.dart';
import 'package:the_runner/core/widgets/loading_overlay.dart';
import 'package:the_runner/data/models/bid_model.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/models/errand_private_details.dart';
import 'package:the_runner/data/models/proof_model.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/presentation/screens/errands/bid_sheet.dart';
import 'package:the_runner/presentation/screens/errands/proof_sheet.dart';
import 'package:the_runner/utils/translate.dart';

/// One errand, seen by whoever opened it. What shows depends on who you
/// are (requester, accepted runner, or a runner browsing) and where the
/// errand is in its lifecycle. Every action that moves money goes
/// through a Cloud Function; the screen just reflects the new status
/// when Firestore streams it back.
///
/// Expects the errand id as the route argument.
class ErrandDetailScreen extends StatefulWidget {
  const ErrandDetailScreen({super.key});

  @override
  State<ErrandDetailScreen> createState() => _ErrandDetailScreenState();
}

class _ErrandDetailScreenState extends State<ErrandDetailScreen> {
  final _repository = AppRepository.errandRepository;
  String? _errandId;

  /// The last errand the stream gave us. Action states (in progress,
  /// success, error) replace ErrandLoaded in the bloc, so the screen
  /// keeps this to stay on screen in between.
  ErrandModel? _errand;
  ErrandStatus? _lastStatus;

  Future<List<BidModel>>? _bids;
  Future<ErrandPrivateDetails?>? _details;
  Future<List<ProofModel>>? _proofs;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_errandId != null) return;
    _errandId = ModalRoute.of(context)?.settings.arguments as String?;
    if (_errandId != null) {
      context.read<ErrandBloc>().add(StreamErrand(_errandId!));
    }
  }

  /// Re-fetch the side data whenever the status changes: the rules
  /// open up the private details and proof at specific stages.
  void _onErrand(ErrandModel errand) {
    _errand = errand;
    if (_lastStatus == errand.status) return;
    _lastStatus = errand.status;
    _bids = _repository.getBidsForErrand(errand.id);
    _details = _repository.getPrivateDetails(errand.id);
    _proofs = errand.status.index >= ErrandStatus.proofSubmitted.index
        ? _repository.getProofs(errand.id)
        : null;
  }

  void _reloadBids() {
    if (_errand == null) return;
    setState(() => _bids = _repository.getBidsForErrand(_errand!.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ErrandBloc, ErrandState>(
      listener: _listen,
      builder: (context, state) {
        if (state is ErrandLoaded) _onErrand(state.errand);
        final errand = _errand;

        if (errand == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: state is ErrandError
                  ? Text(context.errorText(state.message))
                  : const CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ColorConst.backgroundColor,
          appBar: AppBar(title: Text(errandTypeLabel(context, errand.type))),
          body: ListView(
            padding: EdgeInsets.all(SizeConfig.defaultPadding),
            children: [
              _Header(errand: errand),
              _gap(),
              _PriceCard(errand: errand, viewerUid: _uid),
              if (errand.status.isFundsHeld) ...[
                _gap(),
                _EscrowBanner(errand: errand),
              ],
              if (errand.description.isNotEmpty) ...[
                _gap(),
                Text(errand.description, style: FontConst.REGULAR_DEFAULT_16),
              ],
              _gap(),
              _buildDetails(),
              if (_proofs != null) ...[
                _gap(),
                _buildProofs(),
              ],
              if (errand.isRequester(_uid) && errand.status.isBiddable) ...[
                _gap(),
                _buildBidsForRequester(errand),
              ],
            ],
          ),
          bottomNavigationBar: _ActionBar(
            children: _actionsFor(errand),
          ),
        );
      },
    );
  }

  void _listen(BuildContext context, ErrandState state) async {
    if (state is ErrandActionInProgress) {
      LoadingOverlay.show();
      return;
    }
    LoadingOverlay.hide();

    if (state is ErrandActionSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(state.messageKey))),
      );
      _reloadBids();
    } else if (state is ErrandError && _errand != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.errorText(state.message))),
      );
    } else if (state is PaymentLinkReady) {
      // TradeSafe checkout opens in the browser. The errand flips to
      // `funded` by itself when TradeSafe's webhook confirms payment,
      // and this screen updates through the stream.
      final ok = await launchUrl(
        Uri.parse(state.paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_payment_link'))),
        );
      }
    }
  }

  // ── Action bar ──────────────────────────────────────────────

  List<Widget> _actionsFor(ErrandModel errand) {
    final bloc = context.read<ErrandBloc>();
    final uid = _uid;

    if (errand.isRequester(uid)) {
      switch (errand.status) {
        case ErrandStatus.bidding:
          return [_cancelButton(errand)];
        case ErrandStatus.accepted:
          return [
            _cancelButton(errand),
            ElevatedButton(
              onPressed: () => bloc.add(StartPayment(errand.id)),
              child: Text(context.tr('pay_into_escrow', {
                'amount': Fees.format(errand.requesterTotal ?? 0),
              })),
            ),
          ];
        case ErrandStatus.proofSubmitted:
          return [
            OutlinedButton(
              onPressed: () => _dispute(errand),
              child: Text(context.tr('raise_dispute')),
            ),
            ElevatedButton(
              onPressed: () => _confirm(
                titleKey: 'approve_title',
                bodyKey: 'approve_body',
                onYes: () => bloc.add(ApproveCompletion(errand.id)),
              ),
              child: Text(context.tr('approve_and_pay')),
            ),
          ];
        default:
          return const [];
      }
    }

    if (errand.isRunner(uid)) {
      switch (errand.status) {
        case ErrandStatus.accepted:
          return [_InfoText(context.tr('waiting_for_payment'))];
        case ErrandStatus.funded:
          return [
            ElevatedButton(
              onPressed: () => bloc.add(StartErrand(errand.id)),
              child: Text(context.tr('start_errand')),
            ),
          ];
        case ErrandStatus.inProgress:
          return [
            ElevatedButton(
              onPressed: () async {
                final request = await showProofSheet(context, errand: errand);
                if (request != null) bloc.add(SubmitProof(request));
              },
              child: Text(context.tr('submit_proof')),
            ),
          ];
        case ErrandStatus.proofSubmitted:
          return [_InfoText(context.tr('waiting_for_approval'))];
        default:
          return const [];
      }
    }

    // A runner browsing an open errand: bid, or manage their bid.
    if (errand.status.isBiddable) {
      // Only verified runners can bid (the rules enforce it too).
      final auth = context.read<AuthBloc>().state;
      final isRunner = auth is Authenticated && auth.user.isRunner;
      if (!isRunner) {
        return [
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('runner_onboarding_soon'))),
            ),
            child: Text(context.tr('become_a_runner_to_bid')),
          ),
        ];
      }
      return [
        FutureBuilder<List<BidModel>>(
          future: _bids,
          builder: (context, snapshot) {
            final mine = snapshot.data
                ?.where((b) => b.runnerUid == uid && b.status == BidStatus.pending)
                .firstOrNull;
            if (mine == null) {
              return ElevatedButton(
                onPressed: () => _placeBid(errand),
                child: Text(context.tr('place_a_bid')),
              );
            }
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => bloc.add(WithdrawBid(errand.id)),
                    child: Text(context.tr('withdraw')),
                  ),
                ),
                SizedBox(width: SizeConfig.defaultPadding * 0.5),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _placeBid(errand, existing: mine),
                    child: Text(context.tr('edit_bid_amount', {'amount': Fees.format(mine.amount)})),
                  ),
                ),
              ],
            );
          },
        ),
      ];
    }
    return const [];
  }

  Widget _cancelButton(ErrandModel errand) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: ColorConst.errorColor),
      onPressed: () => _confirm(
        titleKey: 'cancel_errand_title',
        bodyKey: errand.status.isFundsHeld ? 'cancel_errand_refund_body' : 'cancel_errand_body',
        onYes: () => context.read<ErrandBloc>().add(CancelErrand(errandId: errand.id)),
      ),
      child: Text(context.tr('cancel_errand')),
    );
  }

  Future<void> _placeBid(ErrandModel errand, {BidModel? existing}) async {
    final input = await showBidSheet(context, errand: errand, existing: existing);
    if (input == null || !mounted) return;
    final bloc = context.read<ErrandBloc>();
    bloc.add(existing == null
        ? PlaceBid(errandId: errand.id, amount: input.amount, message: input.message)
        : UpdateBid(errandId: errand.id, amount: input.amount, message: input.message));
  }

  Future<void> _dispute(ErrandModel errand) async {
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('raise_dispute')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('dispute_explainer'), style: FontConst.REGULAR_SECONDARY_14),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: InputDecoration(hintText: context.tr('dispute_reason_hint')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('send')),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (send == true && text.isNotEmpty && mounted) {
      context.read<ErrandBloc>().add(RaiseDispute(errandId: errand.id, reason: text));
    }
  }

  Future<void> _confirm({
    required String titleKey,
    required String bodyKey,
    required VoidCallback onYes,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(titleKey)),
        content: Text(context.tr(bodyKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('yes')),
          ),
        ],
      ),
    );
    if (yes == true) onYes();
  }

  // ── Sections ────────────────────────────────────────────────

  Widget _buildDetails() {
    return FutureBuilder<ErrandPrivateDetails?>(
      future: _details,
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null) {
          // Browsing runners never see the exact addresses.
          return _Section(
            title: context.tr('where'),
            child: Text(context.tr('exact_address_after_funding'), style: FontConst.REGULAR_SECONDARY_14),
          );
        }
        return _Section(
          title: context.tr('where'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddressRow(icon: Icons.trip_origin_rounded, text: details.pickupAddress),
              if (details.hasDropoff)
                _AddressRow(icon: Icons.place_outlined, text: details.dropoffAddress),
              if (details.instructions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(details.instructions, style: FontConst.REGULAR_DEFAULT),
              ],
              if (details.shoppingList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.tr('shopping_list'), style: FontConst.MEDIUM_DEFAULT_16),
                for (final item in details.shoppingList)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('•  $item', style: FontConst.REGULAR_DEFAULT),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProofs() {
    return FutureBuilder<List<ProofModel>>(
      future: _proofs,
      builder: (context, snapshot) {
        final proofs = snapshot.data ?? const <ProofModel>[];
        if (proofs.isEmpty) return const SizedBox.shrink();
        final proof = proofs.first;
        return _Section(
          title: context.tr('proof'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final url in [...proof.photoUrls, ?proof.receiptUrl])
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 96, height: 96, fit: BoxFit.cover),
                    ),
                ],
              ),
              if (proof.finalPurchaseAmount != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('receipt_came_to', {'amount': Fees.format(proof.finalPurchaseAmount!)}),
                  style: FontConst.MEDIUM_DEFAULT,
                ),
              ],
              if (proof.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(proof.note, style: FontConst.REGULAR_DEFAULT),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBidsForRequester(ErrandModel errand) {
    return FutureBuilder<List<BidModel>>(
      future: _bids,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bids = (snapshot.data ?? const <BidModel>[])
            .where((b) => b.status == BidStatus.pending)
            .toList();
        return _Section(
          title: context.tr('bids_title', {'count': bids.length}),
          trailing: IconButton(
            onPressed: _reloadBids,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: bids.isEmpty
              ? Text(context.tr('no_bids_yet_explainer'), style: FontConst.REGULAR_SECONDARY_14)
              : Column(
                  children: [
                    for (final bid in bids)
                      _BidTile(
                        bid: bid,
                        onAccept: () => _confirm(
                          titleKey: 'accept_bid_title',
                          bodyKey: 'accept_bid_body',
                          onYes: () => context.read<ErrandBloc>().add(
                                AcceptBid(errandId: errand.id, runnerUid: bid.runnerUid),
                              ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _gap() => SizedBox(height: SizeConfig.defaultPadding);
}

// ── Pieces ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ErrandModel errand;

  const _Header({required this.errand});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(errand.title, style: FontConst.BOLD_DEFAULT_24),
        const SizedBox(height: 6),
        Row(
          children: [
            ErrandStatusChip(status: errand.status),
            const SizedBox(width: 8),
            if (errand.areaLabel.isNotEmpty)
              Flexible(
                child: Text(errand.areaLabel, style: FontConst.REGULAR_SECONDARY_14),
              ),
          ],
        ),
        if (errand.deadline != null) ...[
          const SizedBox(height: 6),
          Text(
            context.tr('due_by', {
              'when': '${MaterialLocalizations.of(context).formatMediumDate(errand.deadline!)}, '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(errand.deadline!))}',
            }),
            style: FontConst.REGULAR_SECONDARY_14,
          ),
        ],
      ],
    );
  }
}

/// The money, from the viewer's side: the requester sees what they pay,
/// the runner sees what they receive. Same numbers, no surprises.
class _PriceCard extends StatelessWidget {
  final ErrandModel errand;
  final String? viewerUid;

  const _PriceCard({required this.errand, this.viewerUid});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, bool)>[];
    final fee = errand.agreedFee;
    final budget = errand.purchaseBudget;

    if (fee == null) {
      rows.add((
        context.tr('fee_range'),
        '${Fees.format(errand.startingFee)} – ${Fees.format(errand.feeCap)}',
        true,
      ));
      if (budget != null) rows.add((context.tr('purchase_budget'), Fees.format(budget), false));
    } else if (errand.isRequester(viewerUid)) {
      rows.add((context.tr('runner_fee'), Fees.format(fee), false));
      rows.add((
        context.tr('service_fee'),
        Fees.format(Fees.requesterServiceFee(fee, rate: errand.requesterFeeRate)),
        false,
      ));
      if (budget != null) rows.add((context.tr('purchase_budget'), Fees.format(budget), false));
      rows.add((context.tr('you_pay'), Fees.format(errand.requesterTotal!), true));
    } else {
      rows.add((context.tr('agreed_fee'), Fees.format(fee), false));
      rows.add((
        context.tr('platform_fee'),
        '- ${Fees.format(Fees.runnerPlatformFee(fee, rate: errand.runnerFeeRate))}',
        false,
      ));
      rows.add((context.tr('you_receive'), Fees.format(errand.runnerPayoutFor(fee)), true));
      if (budget != null) {
        rows.add((context.tr('plus_purchase_reimbursed'), Fees.format(budget), false));
      }
    }

    return Container(
      padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.8),
      decoration: BoxDecoration(
        color: ColorConst.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorConst.borderColor),
      ),
      child: Column(
        children: [
          for (final (label, value, bold) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: bold ? FontConst.MEDIUM_DEFAULT_16 : FontConst.REGULAR_SECONDARY_14,
                    ),
                  ),
                  Text(value, style: bold ? FontConst.BOLD_PRIMARY_18 : FontConst.REGULAR_DEFAULT),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EscrowBanner extends StatelessWidget {
  final ErrandModel errand;

  const _EscrowBanner({required this.errand});

  @override
  Widget build(BuildContext context) {
    final release = errand.autoReleaseAt;
    final text = errand.status == ErrandStatus.disputed
        ? context.tr('escrow_frozen_dispute')
        : release != null
            ? context.tr('escrow_auto_release', {
                'hours': release.difference(DateTime.now()).inHours.clamp(0, 24),
              })
            : context.tr('escrow_held', {'amount': Fees.format(errand.escrow.heldAmount)});

    final color = errand.status == ErrandStatus.disputed
        ? ColorConst.errorColor
        : ColorConst.successColor;

    return Container(
      padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: color),
          SizedBox(width: SizeConfig.defaultPadding * 0.5),
          Expanded(child: Text(text, style: FontConst.REGULAR_DEFAULT)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: FontConst.BOLD_DEFAULT_18)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AddressRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ColorConst.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: FontConst.REGULAR_DEFAULT_16)),
        ],
      ),
    );
  }
}

class _BidTile extends StatelessWidget {
  final BidModel bid;
  final VoidCallback onAccept;

  const _BidTile({required this.bid, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AppRepository.authRepository.getUserById(bid.runnerUid),
      builder: (context, snapshot) {
        final runner = snapshot.data;
        final name = (runner?.displayName.isNotEmpty ?? false)
            ? runner!.displayName
            : context.tr('runner_user');
        final rating = runner == null || runner.totalReviews == 0
            ? context.tr('new_runner')
            : '★ ${runner.averageRating.toStringAsFixed(1)} · '
                '${context.tr('errands_done', {'count': runner.totalReviews})}';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(name, style: FontConst.MEDIUM_DEFAULT_16),
            subtitle: Text(
              [
                rating,
                if (bid.message.isNotEmpty) bid.message,
                if (bid.editedAt != null) context.tr('edited'),
              ].join('\n'),
              style: FontConst.REGULAR_SECONDARY_12,
            ),
            isThreeLine: bid.message.isNotEmpty,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fees.format(bid.amount), style: FontConst.BOLD_PRIMARY_16),
                GestureDetector(
                  onTap: onAccept,
                  child: Text(context.tr('accept'), style: FontConst.MEDIUM_SUCCESS_12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;

  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: TextAlign.center, style: FontConst.REGULAR_SECONDARY_14);
  }
}

class _ActionBar extends StatelessWidget {
  final List<Widget> children;

  const _ActionBar({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.8),
        decoration: BoxDecoration(
          color: ColorConst.surfaceColor,
          border: Border(top: BorderSide(color: ColorConst.dividerColor)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: SizeConfig.defaultPadding * 0.5),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}
