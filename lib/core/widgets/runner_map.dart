// lib/core/widgets/runner_map.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as path;
import 'package:the_runner/configs/api_keys.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/core/utils/labels.dart';
import 'package:the_runner/data/models/errand_model.dart';

class RunnerMap extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  /// Errands are plotted at their APPROXIMATE pickup (~1km grid), the
  /// same location every signed-in user can already see.
  final List<ErrandModel> errands;
  final ValueChanged<ErrandModel>? onErrandTap;
  final double initialZoom;
  final MapController? controller;

  const RunnerMap({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.errands = const [],
    this.onErrandTap,
    this.initialZoom = 14,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: path.LatLng(centerLat, centerLng),
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${ApiKeys.mapTiler}',
          userAgentPackageName: 'com.blackworks.therunner',
        ),
        MarkerLayer(
          markers: [
            // Current location marker
            Marker(
              point: path.LatLng(centerLat, centerLng),
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ),
            ...errands.map(
              (errand) => Marker(
                point: path.LatLng(errand.lat, errand.lng),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: onErrandTap == null ? null : () => onErrandTap!(errand),
                  child: _MapPin(
                    color: errand.isShopping
                        ? ColorConst.accentColor
                        : ColorConst.primaryColor,
                    icon: errandTypeIcon(errand.type),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom pin shape (not the default map marker) per design brief -
/// a teardrop with an icon, colored by pin type.
class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        CustomPaint(
          size: const Size(8, 6),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}