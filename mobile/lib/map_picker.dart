import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';
import 'app_language.dart';
import 'app_theme.dart';
import 'location_access.dart';

const _yangonCenter = LatLng(16.8409, 96.1735);
const _mapTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

bool insideServiceArea(
  double latitude,
  double longitude,
  Map<String, dynamic> bounds,
) =>
    latitude >= (bounds['south'] as num).toDouble() &&
    latitude <= (bounds['north'] as num).toDouble() &&
    longitude >= (bounds['west'] as num).toDouble() &&
    longitude <= (bounds['east'] as num).toDouble();

LatLngBounds serviceLatLngBounds(Map<String, dynamic> bounds) => LatLngBounds(
  LatLng(
    (bounds['south'] as num).toDouble(),
    (bounds['west'] as num).toDouble(),
  ),
  LatLng(
    (bounds['north'] as num).toDouble(),
    (bounds['east'] as num).toDouble(),
  ),
);

class MapPlacePicker extends StatefulWidget {
  const MapPlacePicker({
    super.key,
    required this.places,
    required this.city,
    required this.bounds,
    required this.forPickup,
    required this.api,
    this.initial,
  });

  final List<Map<String, dynamic>> places;
  final String city;
  final Map<String, dynamic> bounds;
  final bool forPickup;
  final Api api;
  final Map<String, dynamic>? initial;

  @override
  State<MapPlacePicker> createState() => _MapPlacePickerState();
}

class _MapPlacePickerState extends State<MapPlacePicker> {
  final mapController = MapController();
  final searchController = TextEditingController();
  Timer? cameraDebounce;
  Timer? searchDebounce;
  Timer? reverseDebounce;
  late Map<String, dynamic> selected;
  List<Map<String, dynamic>> searchResults = [];
  String query = '';
  bool locating = false;
  bool moving = false;
  bool searching = false;
  bool resolvingAddress = false;

  @override
  void initState() {
    super.initState();
    selected =
        widget.initial ??
        {
          'latitude': _yangonCenter.latitude,
          'longitude': _yangonCenter.longitude,
          'label': 'Pinned map location',
        };
  }

  @override
  void dispose() {
    cameraDebounce?.cancel();
    searchDebounce?.cancel();
    reverseDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  LatLng get selectedPoint => LatLng(
    (selected['latitude'] as num).toDouble(),
    (selected['longitude'] as num).toDouble(),
  );

  List<Map<String, dynamic>> get localMatches {
    if (query.trim().length < 2) return const [];
    final needle = query.toLowerCase();
    return widget.places
        .where(
          (place) =>
              '${place['name']} ${place['area']} '
                      '${AppLanguage.place(context, '${place['name']}')} '
                      '${AppLanguage.place(context, '${place['area']}')}'
                  .toLowerCase()
                  .contains(needle),
        )
        .take(4)
        .toList();
  }

  List<Map<String, dynamic>> get matches =>
      searchResults.isNotEmpty ? searchResults : localMatches;

  void _searchChanged(String value) {
    setState(() {
      query = value;
      searchResults = [];
    });
    searchDebounce?.cancel();
    final text = value.trim();
    if (text.length < 2) return;
    searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted || searchController.text.trim() != text) return;
      setState(() => searching = true);
      try {
        final response = await widget.api.get(
          '/geocoding/search?q=${Uri.encodeQueryComponent(text)}',
        );
        if (!mounted || searchController.text.trim() != text) return;
        setState(() {
          searchResults = (response['results'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
        });
      } catch (_) {
        // The bundled Yangon landmarks remain available if geocoding is down.
      } finally {
        if (mounted && searchController.text.trim() == text) {
          setState(() => searching = false);
        }
      }
    });
  }

  void _resolveAddress(LatLng point) {
    reverseDebounce?.cancel();
    reverseDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => resolvingAddress = true);
      try {
        final response = await widget.api.get(
          '/geocoding/reverse?latitude=${point.latitude}&longitude=${point.longitude}',
        );
        final place = response['place'] as Map<String, dynamic>?;
        if (!mounted || place == null) return;
        final current = selectedPoint;
        if ((current.latitude - point.latitude).abs() > .00001 ||
            (current.longitude - point.longitude).abs() > .00001) {
          return;
        }
        setState(() {
          selected = {
            'latitude': point.latitude,
            'longitude': point.longitude,
            'label': place['label'] ?? place['name'] ?? 'Pinned map location',
          };
        });
      } catch (_) {
        // Coordinates are still valid when an address cannot be resolved.
      } finally {
        if (mounted) setState(() => resolvingAddress = false);
      }
    });
  }

  void _setSelection(
    LatLng point, {
    String label = 'Pinned map location',
    String? id,
    bool moveMap = true,
  }) {
    if (!insideServiceArea(point.latitude, point.longitude, widget.bounds)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.text(
              context,
              'Choose a point inside the Yangon service area.',
            ),
          ),
        ),
      );
      return;
    }
    final selection = <String, dynamic>{
      'latitude': point.latitude,
      'longitude': point.longitude,
      'label': label,
    };
    if (id != null) selection['id'] = id;
    setState(() {
      selected = selection;
      query = '';
      searchResults = [];
      searchController.clear();
      moving = false;
    });
    FocusScope.of(context).unfocus();
    if (moveMap) mapController.move(point, 16);
    if (label == 'Pinned map location' || label == 'My current location') {
      _resolveAddress(point);
    }
  }

  void _selectPlace(Map<String, dynamic> place) => _setSelection(
    LatLng(
      (place['latitude'] as num).toDouble(),
      (place['longitude'] as num).toDouble(),
    ),
    id: place['id']?.toString(),
    label: place['name']?.toString() ?? 'Pinned map location',
  );

  void _cameraMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    cameraDebounce?.cancel();
    if (!moving) setState(() => moving = true);
    cameraDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _setSelection(camera.center, moveMap: false);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => locating = true);
    try {
      final position = await currentPositionWithRecovery(context);
      if (!mounted) return;
      _setSelection(
        LatLng(position.latitude, position.longitude),
        label: 'My current location',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.forPickup;
    final accent = pickup ? taxiBlue : const Color(0xFFE83A66);
    final label = AppLanguage.place(context, selected['label'].toString());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguage.text(
                context,
                pickup ? 'Set pickup location' : 'Set destination location',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              AppLanguage.text(context, 'Move the map to position the pin'),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: selectedPoint,
              initialZoom: 15,
              minZoom: 10,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: serviceLatLngBounds(widget.bounds),
              ),
              onTap: (_, point) => _setSelection(point),
              onPositionChanged: _cameraMoved,
            ),
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0x55EAF3FA),
                  BlendMode.screen,
                ),
                child: TileLayer(
                  urlTemplate: _mapTiles,
                  userAgentPackageName: 'com.gooddaykilotaxi.mobile',
                ),
              ),
              const RichAttributionWidget(
                showFlutterMapAttribution: false,
                attributions: [TextSourceAttribution('OpenStreetMap')],
              ),
            ],
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Material(
                  color: Colors.white,
                  elevation: 5,
                  shadowColor: const Color(0x3300214B),
                  borderRadius: BorderRadius.circular(18),
                  child: TextField(
                    controller: searchController,
                    onChanged: _searchChanged,
                    decoration: InputDecoration(
                      hintText: AppLanguage.text(
                        context,
                        'Search Yangon landmarks',
                      ),
                      prefixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.search_rounded, color: accent),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                query = '';
                                searchResults = [];
                                searchController.clear();
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (matches.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x2600214B), blurRadius: 18),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (final place in matches)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor: accent.withValues(alpha: .12),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: accent,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              AppLanguage.place(
                                context,
                                (place['name'] ?? place['label']).toString(),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              AppLanguage.place(
                                context,
                                (place['area'] ?? '').toString(),
                              ),
                            ),
                            onTap: () => _selectPlace(place),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: AnimatedScale(
                  scale: moving ? 1.12 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x5500214B),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          pickup
                              ? Icons.person_pin_circle_rounded
                              : Icons.flag_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Container(width: 3, height: 13, color: accent),
                      Container(
                        width: moving ? 19 : 12,
                        height: moving ? 7 : 5,
                        decoration: BoxDecoration(
                          color: const Color(0x5500214B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 205,
            child: FloatingActionButton.small(
              heroTag: 'map-current-location',
              onPressed: locating ? null : _useCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: taxiBlue,
              elevation: 5,
              child: locating
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3300214B),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DBE5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: accent.withValues(alpha: .12),
                          child: Icon(
                            pickup
                                ? Icons.radio_button_checked_rounded
                                : Icons.flag_rounded,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLanguage.text(
                                  context,
                                  pickup ? 'Pickup point' : 'Destination point',
                                ),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                moving || resolvingAddress
                                    ? AppLanguage.text(
                                        context,
                                        'Finding this location…',
                                      )
                                    : label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${selectedPoint.latitude.toStringAsFixed(5)}, '
                                '${selectedPoint.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    FilledButton(
                      onPressed: moving
                          ? null
                          : () => Navigator.pop(context, selected),
                      child: Text(
                        AppLanguage.text(
                          context,
                          pickup ? 'Confirm pickup' : 'Confirm destination',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({super.key, required this.quote});

  final Map<String, dynamic> quote;

  @override
  Widget build(BuildContext context) {
    final rawCoordinates =
        (quote['route_geometry'] as Map<String, dynamic>?)?['coordinates']
            as List? ??
        const [];
    final points = rawCoordinates
        .whereType<List>()
        .where((coordinate) => coordinate.length >= 2)
        .map(
          (coordinate) => LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
        )
        .toList();
    if (points.length < 2) return const SizedBox.shrink();
    final driver = quote['driver'] as Map<String, dynamic>?;
    final driverLatitude = driver?['latitude'] as num?;
    final driverLongitude = driver?['longitude'] as num?;
    final driverPoint = driverLatitude != null && driverLongitude != null
        ? LatLng(driverLatitude.toDouble(), driverLongitude.toDouble())
        : null;
    final cameraPoints = [...points, ?driverPoint];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 190,
        child: FlutterMap(
          options: MapOptions(
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(cameraPoints),
              padding: const EdgeInsets.all(30),
            ),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x55EAF3FA),
                BlendMode.screen,
              ),
              child: TileLayer(
                urlTemplate: _mapTiles,
                userAgentPackageName: 'com.gooddaykilotaxi.mobile',
              ),
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 7,
                  color: taxiBlue,
                  borderStrokeWidth: 3,
                  borderColor: Colors.white,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 38,
                  height: 38,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.radio_button_checked_rounded,
                      color: taxiBlue,
                      size: 32,
                    ),
                  ),
                ),
                Marker(
                  point: points.last,
                  width: 38,
                  height: 38,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      color: Color(0xFFE83A66),
                      size: 28,
                    ),
                  ),
                ),
                if (driverPoint != null)
                  Marker(
                    point: driverPoint,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: taxiYellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(color: Color(0x5500214B), blurRadius: 10),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_taxi_rounded,
                        color: ink,
                        size: 27,
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [TextSourceAttribution('OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }
}
