// lib/presentation/screens/home/home_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/friendly_error.dart';
import 'package:the_runner/core/utils/labels.dart';
import 'package:the_runner/core/widgets/errand_card.dart';
import 'package:the_runner/core/widgets/runner_map.dart';
import 'package:the_runner/data/local/search_radius_preference.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/services/errand_changes.dart';
import 'package:the_runner/data/services/geohash_service.dart';
import 'package:the_runner/data/services/location_accuracy_check.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/presentation/common_blocs/location/location.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_bloc.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_state.dart';
import 'package:the_runner/utils/translate.dart';

/// The runner's feed: errands still open for bids near you, closest
/// deadline first. Requesters post from the button at the bottom.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  double? _lat;
  double? _lng;
  ErrandType? _typeFilter;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    context.read<LocationBloc>().add(RequestPermission());
    // Bids placed or withdrawn elsewhere change what belongs in the feed.
    ErrandChanges.listenable.addListener(_load);
  }

  @override
  void dispose() {
    ErrandChanges.listenable.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted || _lat == null || _lng == null) {
      debugPrint('[ErrandFeed] not loading yet: no location');
      return;
    }
    debugPrint('[ErrandFeed] loading around ($_lat, $_lng)');
    context.read<ErrandBloc>().add(LoadOpenErrandsNearby(
          lat: _lat!,
          lng: _lng!,
          radiusKm: SearchRadiusPreference.get(),
          type: _typeFilter,
        ));
  }

  Future<void> _openErrand(ErrandModel errand) async {
    await Navigator.of(context).pushNamed(AppRouter.errandDetail, arguments: errand.id);
    // Your bid may have changed the list (or the errand closed).
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      body: MultiBlocListener(
        listeners: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationLoaded) {
                // The same position arrives twice (coordinates, then
                // again with the street address): only reload if it moved.
                final moved = state.latitude != _lat || state.longitude != _lng;
                _lat = state.latitude;
                _lng = state.longitude;
                if (moved) _load();
              }
            },
          ),
          // This tab stays mounted in the bottom nav, so a radius change
          // in Settings has to reload it explicitly.
          BlocListener<AppSettingsBloc, AppSettingsState>(
            listenWhen: (before, after) => before.searchRadiusKm != after.searchRadiusKm,
            listener: (context, state) => _load(),
          ),
        ],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  SizeConfig.defaultPadding,
                  SizeConfig.defaultPadding,
                  SizeConfig.defaultPadding,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _LocationBar()),
                        IconButton(
                          tooltip: context.tr(_showMap ? 'show_list' : 'show_map'),
                          onPressed: () => setState(() => _showMap = !_showMap),
                          icon: Icon(
                            _showMap ? Icons.list_rounded : Icons.map_outlined,
                            color: ColorConst.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const _ApproximateLocationNotice(),
                  ],
                ),
              ),
              _buildTypeFilter(),
              Expanded(child: _showMap ? _buildMap() : _buildList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_post_errand_fab',
        backgroundColor: ColorConst.accentColor,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRouter.newErrand);
          // This tab lives inside IndexedStack and never re-runs
          // initState, so refresh explicitly on return.
          if (mounted) _load();
        },
        icon: const Icon(Icons.add_task_rounded),
        label: Text(context.tr('post_an_errand')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTypeFilter() {
    Widget chip(String label, ErrandType? type) {
      final selected = _typeFilter == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          selectedColor: ColorConst.primaryColor.withValues(alpha: 0.15),
          labelStyle: selected ? FontConst.MEDIUM_PRIMARY : FontConst.REGULAR_DEFAULT,
          onSelected: (_) {
            setState(() => _typeFilter = type);
            _load();
          },
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.defaultPadding,
          vertical: 8,
        ),
        children: [
          chip(context.tr('all'), null),
          for (final type in ErrandType.values) chip(errandTypeLabel(context, type), type),
        ],
      ),
    );
  }

  Widget _buildList() {
    return BlocBuilder<ErrandBloc, ErrandState>(
      buildWhen: (_, state) =>
          state is ErrandLoading || state is ErrandsListLoaded || state is ErrandError,
      builder: (context, state) {
        if (state is ErrandLoading || state is ErrandInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ErrandError) {
          return _Message(
            icon: Icons.cloud_off_rounded,
            text: context.errorText(state.message),
            onRetry: _load,
          );
        }
        final errands = state is ErrandsListLoaded ? state.errands : <ErrandModel>[];
        if (errands.isEmpty) {
          // Most of South Africa is quiet at launch while Durban is
          // seeded first: say so kindly, and turn it into a runner
          // sign-up rather than a dead end.
          return _Message(
            icon: Icons.directions_run_rounded,
            text: context.tr('no_errands_nearby', {
              'km': SearchRadiusPreference.get().toStringAsFixed(0),
            }),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              SizeConfig.defaultPadding,
              0,
              SizeConfig.defaultPadding,
              SizeConfig.defaultPadding * 5,
            ),
            itemCount: errands.length,
            separatorBuilder: (_, _) => SizedBox(height: SizeConfig.defaultPadding * 0.5),
            itemBuilder: (context, i) {
              final errand = errands[i];
              return ErrandCard(
                errand: errand,
                showStatus: false,
                distanceMeters: _lat == null
                    ? null
                    : GeohashService.distanceMeters(_lat!, _lng!, errand.lat, errand.lng),
                onTap: () => _openErrand(errand),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    if (_lat == null || _lng == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return BlocBuilder<ErrandBloc, ErrandState>(
      buildWhen: (_, state) => state is ErrandsListLoaded,
      builder: (context, state) {
        final errands = state is ErrandsListLoaded ? state.errands : <ErrandModel>[];
        return RunnerMap(
          centerLat: _lat!,
          centerLng: _lng!,
          errands: errands,
          onErrandTap: _openErrand,
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SizeConfig.defaultPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ColorConst.textSecondaryColor),
            SizedBox(height: SizeConfig.defaultPadding * 0.6),
            Text(text, textAlign: TextAlign.center, style: FontConst.REGULAR_SECONDARY_14),
            if (onRetry != null) ...[
              SizedBox(height: SizeConfig.defaultPadding * 0.6),
              TextButton(onPressed: onRetry, child: Text(context.tr('try_again'))),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        String label = context.tr('finding_location');
        if (state is LocationLoaded) {
          // Address can lag behind (or fail): the feed still works.
          label = state.address ?? context.tr('current_location');
        } else if (state is PermissionDenied || state is PermissionDeniedForever) {
          label = context.tr('location_unavailable_tap');
        }
 
        // Tapping this always used to dispatch RequestPermission(),
        // regardless of whether permission was already granted. Once
        // granted, re-requesting it does nothing useful - no OS dialog
        // fires, and critically, no fresh GPS fetch is triggered either.
        // That made this bar's "tap to refresh" behavior a no-op:
        // it re-emitted whatever position was already cached, instantly,
        // which looked exactly like "refresh fell straight back to the
        // wrong location." Now it only requests permission while that's
        // actually still needed; once granted, tapping forces a real
        // fresh position fetch instead.
        final needsPermission = state is PermissionDenied || state is PermissionDeniedForever;
 
        return InkWell(
          onTap: () => context.read<LocationBloc>().add(
                needsPermission ? RequestPermission() : GetCurrentLocation(true),
              ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.defaultPadding * 0.8,
              vertical: SizeConfig.defaultPadding * 0.5,
            ),
            decoration: BoxDecoration(
              color: ColorConst.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: ColorConst.primaryColor),
                SizedBox(width: SizeConfig.defaultPadding * 0.3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontConst.MEDIUM_DEFAULT_16.copyWith(
                      fontSize: SizeConfig.defaultSize * 1.3,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: ColorConst.textSecondaryColor),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApproximateLocationNotice extends StatefulWidget {
  const _ApproximateLocationNotice();
 
  @override
  State<_ApproximateLocationNotice> createState() => _ApproximateLocationNoticeState();
}
 
class _ApproximateLocationNoticeState extends State<_ApproximateLocationNotice>
    with WidgetsBindingObserver {
  bool _isApproximate = false;
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }
 
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }
 
  Future<void> _check() async {
    final approximate = await LocationAccuracyCheck.isApproximateOnly();
    if (mounted && approximate != _isApproximate) {
      setState(() => _isApproximate = approximate);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    if (!_isApproximate) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.defaultPadding * 0.5),
      child: InkWell(
        onTap: LocationAccuracyCheck.openSettings,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.6),
          decoration: BoxDecoration(
            color: ColorConst.warningColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.location_searching_rounded, size: 18, color: ColorConst.warningColor),
              SizedBox(width: SizeConfig.defaultPadding * 0.5),
              Expanded(
                child: Text(
                  context.tr('approximate_location_notice'),
                  style: FontConst.REGULAR_SECONDARY_12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
