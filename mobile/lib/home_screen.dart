import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'account_settings.dart';
import 'app_language.dart';
import 'app_theme.dart';
import 'map_picker.dart';
import 'location_access.dart';
import 'ride_history.dart';
import 'push_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.token,
    required this.user,
    required this.onSignOut,
    required this.onUserUpdated,
  });
  final String token;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  final ValueChanged<Map<String, dynamic>> onUserUpdated;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Api api = Api(widget.token);
  final ratingComment = TextEditingController();
  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? pickup;
  Map<String, dynamic>? destination;
  Map<String, dynamic>? quote;
  Map<String, dynamic>? booking;
  List<Map<String, dynamic>> offers = [];
  Position? driverPosition;
  bool demoDriverLocation = false;
  StreamSubscription<Position>? locationSubscription;
  DateTime? lastLocationUpload;
  bool locationUploadInFlight = false;
  int? dismissedBookingId;
  String city = 'Yangon';
  Map<String, dynamic> cityBounds = {
    'south': 16.55,
    'north': 17.20,
    'west': 95.85,
    'east': 96.50,
  };
  bool online = false;
  String driverApprovalStatus = 'pending';
  bool busy = false;
  bool streaming = false;
  int selectedRating = 0;
  bool get isDriver => widget.user['role'] == 'driver';
  bool get driverApproved => driverApprovalStatus == 'approved';
  bool get hasActiveDriverRide =>
      isDriver &&
      (booking?['status'] == 'accepted' || booking?['status'] == 'started');
  String _t(String english) => AppLanguage.text(context, english);

  @override
  void initState() {
    super.initState();
    _refresh();
    _listen();
    PushNotifications.register(api);
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    ratingComment.dispose();
    super.dispose();
  }

  void _message(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('$error'))));
    }
  }

  Future<void> _refresh() async {
    try {
      final settings = await api.get('/settings');
      if (mounted) {
        setState(() {
          city = settings['city']?.toString() ?? 'Yangon';
          cityBounds =
              (settings['city_bounds'] as Map<String, dynamic>?) ?? cityBounds;
        });
      }
      final current = await api.get('/bookings/active');
      if (mounted) {
        setState(() => booking = current['booking'] as Map<String, dynamic>?);
      }
      if (isDriver) {
        final status = await api.get('/driver/status');
        if (mounted) {
          setState(() {
            online = status['is_available'] == true;
            driverApprovalStatus =
                status['approval_status']?.toString() ?? 'pending';
          });
          _syncLocationTracking();
        }
        final pending = await api.get('/driver/offers');
        if (mounted) {
          setState(
            () => offers = (pending['offers'] as List)
                .cast<Map<String, dynamic>>(),
          );
        }
      } else {
        final catalog = await api.get('/places');
        if (mounted) {
          setState(() {
            city = catalog['city']?.toString() ?? 'Yangon';
            places = (catalog['places'] as List).cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      _message(e);
    }
  }

  Future<void> _listen() async {
    while (mounted) {
      try {
        await for (final snapshot in api.snapshots()) {
          if (!mounted) return;
          setState(() {
            streaming = true;
            final incoming = snapshot['booking'] as Map<String, dynamic>?;
            if (incoming == null || incoming['id'] != dismissedBookingId) {
              booking = incoming;
            }
            if (isDriver) {
              online = snapshot['driver_online'] == true;
              driverApprovalStatus =
                  snapshot['driver_approval_status']?.toString() ??
                  driverApprovalStatus;
              offers = (snapshot['offers'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
            }
          });
          _syncLocationTracking();
        }
      } catch (_) {
        /* Reconnect after a short pause. */
      }
      if (mounted) setState(() => streaming = false);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _pickPlace({required bool forPickup}) async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPlacePicker(
          places: places,
          city: city,
          bounds: cityBounds,
          forPickup: forPickup,
          api: api,
          initial: forPickup ? pickup : destination,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (forPickup) {
        pickup = selected;
      } else {
        destination = selected;
      }
      quote = null;
    });
    if (pickup != null && destination != null) await _getQuote();
  }

  Future<Position> _currentPosition() async {
    return currentPositionWithRecovery(context);
  }

  Future<void> _useCurrentPickup() async {
    setState(() => busy = true);
    try {
      final position = await _currentPosition();
      if (!insideServiceArea(
        position.latitude,
        position.longitude,
        cityBounds,
      )) {
        throw ApiException(
          _t(
            'Your current location is outside Greater Yangon. Choose a pickup on the map.',
          ),
        );
      }
      if (mounted) {
        setState(() {
          pickup = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'label': 'My current location',
          };
          quote = null;
        });
      }
      if (destination != null) await _getQuote();
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Map<String, dynamic> _selectionBody(Map<String, dynamic> selection) {
    if (selection['id'] != null) return {'place_id': selection['id']};
    return {
      'latitude': selection['latitude'],
      'longitude': selection['longitude'],
      'label': selection['label'],
    };
  }

  Future<void> _getQuote() async {
    if (pickup == null || destination == null) return;
    setState(() => busy = true);
    try {
      final result = await api.post('/quotes', {
        'pickup': _selectionBody(pickup!),
        'destination': _selectionBody(destination!),
      });
      if (mounted) setState(() => quote = result);
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _book() async {
    if (quote == null) return;
    setState(() => busy = true);
    try {
      final result = await api.post('/bookings', {
        'quote_id': quote!['quote_id'],
      });
      if (mounted) {
        setState(() {
          booking = result;
          dismissedBookingId = null;
        });
      }
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitRating() async {
    if (booking == null || selectedRating == 0) {
      _message(_t('Choose a star rating first.'));
      return;
    }
    setState(() => busy = true);
    try {
      final result = await api.post('/bookings/${booking!['id']}/rating', {
        'rating': selectedRating,
        if (ratingComment.text.trim().isNotEmpty)
          'comment': ratingComment.text.trim(),
      });
      if (mounted) {
        setState(() {
          booking = result;
          ratingComment.clear();
        });
      }
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _message(_t('Phone number is not available.'));
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
    if (!opened) _message(_t('Could not open the phone app.'));
  }

  Future<void> _action(int id, String action) async {
    setState(() => busy = true);
    try {
      final result = await api.post('/bookings/$id/$action', {});
      if (mounted) {
        setState(() {
          booking = action == 'complete' ? null : result;
          if (isDriver && action == 'accept') online = false;
          if (isDriver && action == 'complete') online = true;
          offers = [];
        });
        _syncLocationTracking();
      }
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleOnline() async {
    if (!driverApproved) {
      _message(_t('Your driver account is waiting for admin approval.'));
      return;
    }
    setState(() => busy = true);
    try {
      final enabled = !online;
      var latitude = driverPosition?.latitude;
      var longitude = driverPosition?.longitude;
      if (enabled) {
        driverPosition = await _currentPosition();
        latitude = driverPosition!.latitude;
        longitude = driverPosition!.longitude;
        demoDriverLocation = false;
        if (!insideServiceArea(latitude, longitude, cityBounds)) {
          if (!mounted) return;
          final useDemo = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.location_off_rounded, color: taxiBlue),
              title: Text(_t('Outside the Yangon service area')),
              content: Text(
                _t(
                  'Your GPS location is outside Greater Yangon. Use a Yangon demo location to test driver bookings.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_t('Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_t('Use demo location')),
                ),
              ],
            ),
          );
          if (useDemo != true) return;
          latitude = 16.7745;
          longitude = 96.1582;
          demoDriverLocation = true;
        }
        if (!demoDriverLocation && mounted) {
          await ensureBackgroundLocationAccess(context);
        }
      }
      final response = await api.put(
        '/driver/location',
        enabled
            ? {
                'latitude': latitude,
                'longitude': longitude,
                'is_available': true,
              }
            : {'is_available': false},
      );
      if (mounted) setState(() => online = response['is_available'] == true);
      _syncLocationTracking();
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _uploadDriverLocation(Position? position) async {
    if (!online && !hasActiveDriverRide) return;
    if (locationUploadInFlight) return;
    final now = DateTime.now();
    if (lastLocationUpload != null &&
        now.difference(lastLocationUpload!) < const Duration(seconds: 10)) {
      return;
    }
    locationUploadInFlight = true;
    lastLocationUpload = now;
    try {
      if (position != null) driverPosition = position;
      if (!demoDriverLocation && driverPosition == null) return;
      await api.put('/driver/location', {
        'latitude': demoDriverLocation ? 16.7745 : driverPosition!.latitude,
        'longitude': demoDriverLocation ? 96.1582 : driverPosition!.longitude,
        'is_available': !hasActiveDriverRide && online,
      });
    } catch (_) {
      // A later background update will retry; avoid repeated technical popups.
    } finally {
      locationUploadInFlight = false;
    }
  }

  void _syncLocationTracking() {
    final shouldTrack = online || hasActiveDriverRide;
    if (!shouldTrack) {
      locationSubscription?.cancel();
      locationSubscription = null;
      lastLocationUpload = null;
      return;
    }
    final locationSettings =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: _t('Driver location sharing is active'),
              notificationText: _t(
                'Passengers can see your taxi while you are online or on a ride.',
              ),
              notificationChannelName: 'Driver location',
              enableWakeLock: true,
              setOngoing: true,
              color: taxiBlue,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    locationSubscription ??=
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _uploadDriverLocation,
          onError: (_) {
            locationSubscription?.cancel();
            locationSubscription = null;
          },
        );
    if (driverPosition != null) _uploadDriverLocation(driverPosition);
  }

  String _label(Map<String, dynamic>? value) {
    final label = value?['label']?.toString() ?? value?['name']?.toString();
    return label == null
        ? _t('Choose a location')
        : AppLanguage.place(context, label);
  }

  String _fare(Map<String, dynamic> data) {
    final value = (data['fare_minor'] as num).toInt();
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return data['currency'] == 'MMK'
        ? AppLanguage.isMyanmar(context)
              ? '$formatted ကျပ်'
              : 'Ks $formatted'
        : '${data['currency']} $formatted';
  }

  void _newRide() {
    setState(() {
      dismissedBookingId = booking?['id'] as int?;
      booking = null;
      quote = null;
      pickup = null;
      destination = null;
      selectedRating = 0;
      ratingComment.clear();
    });
  }

  Future<void> _openAccount() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSettingsPage(
          api: api,
          user: widget.user,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
    if (updated != null) widget.onUserUpdated(updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Image.asset(
        'assets/logo-header-white.png',
        width: 150,
        height: 46,
        fit: BoxFit.contain,
        semanticLabel: 'Good Day Kilo Taxi logo',
      ),
      actions: [
        Center(
          child: Tooltip(
            message: _t(streaming ? '● Live' : '○ Connecting'),
            child: Text(
              streaming ? '●' : '○',
              style: TextStyle(
                color: streaming ? taxiYellow : Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const LanguageToggle(),
        IconButton(
          tooltip: _t('My rides'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RideHistoryPage(api: api)),
          ),
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: _t('My account'),
          onPressed: _openAccount,
          icon: const Icon(Icons.account_circle_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: isDriver ? _driverBody() : _passengerBody(),
          ),
        ),
      ),
    ),
  );

  Widget _passengerBody() {
    final status = booking?['status'];
    if (status == 'searching' || status == 'accepted' || status == 'started') {
      return _activePassenger();
    }
    if (booking != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderIllustration(city: city),
          const SizedBox(height: 20),
          Text(
            _t(
              status == 'completed'
                  ? 'Ride completed'
                  : status == 'unfulfilled'
                  ? 'No driver found'
                  : 'Ride cancelled',
            ),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t('Ready to travel again?'),
            style: const TextStyle(color: muted),
          ),
          if (status == 'completed') ...[
            const SizedBox(height: 18),
            _ratingCard(),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _newRide,
            child: Text(_t('Plan another ride')),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surface(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF0B9),
                child: Icon(Icons.wb_sunny_rounded, color: Color(0xFFD99100)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Good day!'),
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _t('Where to today?'),
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _t(
            'Choose a pickup and destination in {city}.',
          ).replaceAll('{city}', AppLanguage.place(context, city)),
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 19),
        _locationCard(
          'PICKUP',
          _label(pickup),
          Icons.radio_button_checked_rounded,
          () => _pickPlace(forPickup: true),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy ? null : _useCurrentPickup,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(_t('Use my location')),
          ),
        ),
        _locationCard(
          'DESTINATION',
          _label(destination),
          Icons.flag_rounded,
          () => _pickPlace(forPickup: false),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Search a landmark or tap anywhere inside the Yangon service area. Road distance is calculated automatically.',
          ),
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (!busy &&
            pickup != null &&
            destination != null &&
            quote == null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _getQuote,
            icon: const Icon(Icons.route_rounded),
            label: Text(_t('Calculate fare')),
          ),
        ],
        if (quote != null) ...[
          const SizedBox(height: 22),
          RoutePreviewMap(quote: quote!),
          const SizedBox(height: 14),
          _fareCard(quote!),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _book,
            child: Text(_t('Book a taxi')),
          ),
        ],
        const SizedBox(height: 20),
        HeaderIllustration(city: city),
      ],
    );
  }

  Widget _ratingCard() {
    final existing = booking?['rating'] as Map<String, dynamic>?;
    if (existing != null) {
      final score = (existing['score'] as num? ?? 0).toInt();
      return _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Your driver rating'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < score
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: taxiYellow,
                  size: 28,
                ),
              ),
            ),
            if ('${existing['comment'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '${existing['comment']}',
                style: const TextStyle(color: muted),
              ),
            ],
          ],
        ),
      );
    }

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('How was your driver?'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            _t('Your feedback helps improve Good Day Kilo Taxi.'),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                tooltip: '${index + 1}',
                onPressed: busy
                    ? null
                    : () => setState(() => selectedRating = index + 1),
                icon: Icon(
                  index < selectedRating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: taxiYellow,
                  size: 34,
                ),
              ),
            ),
          ),
          TextField(
            controller: ratingComment,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _t('Optional feedback'),
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: busy ? null : _submitRating,
            icon: const Icon(Icons.star_rounded),
            label: Text(_t('Submit rating')),
          ),
        ],
      ),
    );
  }

  Widget _activePassenger() {
    final status = booking!['status'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderIllustration(city: city),
        const SizedBox(height: 22),
        _eyebrow(_t('YOUR RIDE')),
        const SizedBox(height: 8),
        Text(
          _t(
            status == 'searching'
                ? 'Finding your driver'
                : status == 'accepted'
                ? 'Driver on the way'
                : 'Ride in progress',
          ),
          style: const TextStyle(
            fontSize: 28,
            color: ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (status == 'searching') ...[
          const LinearProgressIndicator(color: liveGreen),
          const SizedBox(height: 10),
          Text(
            _t('Nearby drivers can accept this request.'),
            style: const TextStyle(color: muted),
          ),
        ],
        if (booking!['driver'] != null) ...[
          const SizedBox(height: 8),
          _surface(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE4F3FF),
                  child: Icon(Icons.local_taxi_rounded, color: taxiBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${booking!['driver']['name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${booking!['driver']['vehicle_plate']}',
                        style: const TextStyle(color: muted),
                      ),
                      if (booking!['driver']['distance_to_pickup_meters'] !=
                          null)
                        Text(
                          _t('Driver is {distance} km from pickup').replaceAll(
                            '{distance}',
                            ((booking!['driver']['distance_to_pickup_meters']
                                            as num)
                                        .toDouble() /
                                    1000)
                                .toStringAsFixed(1),
                          ),
                          style: const TextStyle(
                            color: liveGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if ('${booking!['driver']['phone'] ?? ''}'.isNotEmpty)
                  IconButton.filled(
                    tooltip: _t('Call driver'),
                    onPressed: () =>
                        _callPhone(booking!['driver']['phone']?.toString()),
                    icon: const Icon(Icons.call_rounded),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _tripCard(booking!),
        const SizedBox(height: 14),
        if (booking!['driver']?['latitude'] != null) ...[
          Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: liveGreen, size: 18),
              const SizedBox(width: 7),
              Text(
                _t('Live driver location'),
                style: const TextStyle(
                  color: liveGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        RoutePreviewMap(quote: booking!),
        const SizedBox(height: 14),
        _fareCard(booking!),
        if (status != 'started') ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => _action(booking!['id'] as int, 'cancel'),
            child: Text(_t('Cancel ride')),
          ),
        ],
      ],
    );
  }

  Widget _driverBody() {
    final status = booking?['status'];
    final awaitingApproval = !driverApproved && !hasActiveDriverRide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderIllustration(city: city),
        const SizedBox(height: 22),
        _eyebrow(_t('DRIVER MODE')),
        const SizedBox(height: 8),
        Text(
          _t(
            status == 'accepted'
                ? 'Head to pickup'
                : status == 'started'
                ? 'Ride in progress'
                : awaitingApproval
                ? driverApprovalStatus == 'rejected'
                      ? 'Driver account not approved'
                      : 'Account review pending'
                : online
                ? 'You are online'
                : 'You are offline',
          ),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 14),
        if (awaitingApproval) ...[
          _surface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  driverApprovalStatus == 'rejected'
                      ? Icons.block_rounded
                      : Icons.verified_user_outlined,
                  color: driverApprovalStatus == 'rejected'
                      ? const Color(0xFFC53030)
                      : taxiBlue,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          driverApprovalStatus == 'rejected'
                              ? 'Please contact Good Day Kilo Taxi support.'
                              : 'An admin must approve your driver account before you can go online.',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _t('Pull down or reopen the app after approval.'),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (online || hasActiveDriverRide) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: liveGreen,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _t('Background driver tracking is active'),
                    style: const TextStyle(
                      color: Color(0xFF146B38),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (status == 'accepted' || status == 'started') ...[
          if (booking!['passenger'] != null) ...[
            _surface(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE4F3FF),
                    child: Icon(Icons.person_rounded, color: taxiBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${booking!['passenger']['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${booking!['passenger']['phone'] ?? ''}',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  if ('${booking!['passenger']['phone'] ?? ''}'.isNotEmpty)
                    IconButton.filled(
                      tooltip: _t('Call passenger'),
                      onPressed: () => _callPhone(
                        booking!['passenger']['phone']?.toString(),
                      ),
                      icon: const Icon(Icons.call_rounded),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _tripCard(booking!),
          const SizedBox(height: 14),
          RoutePreviewMap(quote: booking!),
          const SizedBox(height: 14),
          _fareCard(booking!),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy
                ? null
                : () => _action(
                    booking!['id'] as int,
                    status == 'accepted' ? 'start' : 'complete',
                  ),
            child: Text(
              _t(status == 'accepted' ? 'Start ride' : 'Complete ride'),
            ),
          ),
        ] else if (driverApproved) ...[
          _surface(
            child: Row(
              children: [
                const Icon(Icons.local_taxi_rounded, color: ink, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          online
                              ? 'Receiving requests'
                              : 'Go online to receive rides',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _t('Your location helps us find nearby passengers.'),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: online,
                  onChanged: busy ? null : (_) => _toggleOnline(),
                ),
              ],
            ),
          ),
          if (online && demoDriverLocation) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4C9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_rounded, color: Color(0xFF9B6900)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('Demo location active near Sule Pagoda.'),
                      style: const TextStyle(
                        color: Color(0xFF6A4A00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (offers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _eyebrow(_t('NEW REQUESTS')),
            const SizedBox(height: 12),
            for (final offer in offers) ...[
              _tripCard(offer),
              const SizedBox(height: 8),
              _fareCard(offer),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _action(offer['id'] as int, 'accept'),
                child: Text(_t('Accept ride')),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ],
    );
  }

  Widget _locationCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) => _surface(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: title == 'PICKUP'
                  ? const Color(0xFFE4F3FF)
                  : const Color(0xFFFFE9EF),
              child: Icon(
                icon,
                color: title == 'PICKUP' ? taxiBlue : const Color(0xFFE83A66),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eyebrow(_t(title)),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: value == _t('Choose a location') ? muted : ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    ),
  );

  Widget _tripCard(Map<String, dynamic> trip) => _surface(
    child: Column(
      children: [
        _tripRow(
          Icons.radio_button_checked_rounded,
          'PICKUP',
          _label(trip['pickup'] as Map<String, dynamic>?),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Container(
            height: 23,
            width: 2,
            color: const Color(0xFFD5E5F5),
          ),
        ),
        _tripRow(
          Icons.flag_rounded,
          'DESTINATION',
          _label(trip['destination'] as Map<String, dynamic>?),
        ),
      ],
    ),
  );

  Widget _tripRow(IconData icon, String title, String label) => Row(
    children: [
      Icon(
        icon,
        color: title == 'PICKUP' ? taxiBlue : const Color(0xFFE83A66),
        size: 24,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(_t(title)),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _fareCard(Map<String, dynamic> data) => _surface(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow(_t('APPROXIMATE CASH FARE')),
              const SizedBox(height: 3),
              Text(
                _fare(data),
                style: const TextStyle(
                  fontSize: 27,
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _t('Pay the driver in kyats'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.route_rounded, color: taxiBlue),
            const SizedBox(height: 4),
            Text(
              '${((data['distance_meters'] as num) / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _surface({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD9E9F8)),
    ),
    child: child,
  );

  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: taxiBlue,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
    ),
  );
}

class PlacePicker extends StatefulWidget {
  const PlacePicker({super.key, required this.places, required this.city});
  final List<Map<String, dynamic>> places;
  final String city;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.places
        .where(
          (place) =>
              '${place['name']} ${place['area']} '
                      '${AppLanguage.place(context, '${place['name']}')} '
                      '${AppLanguage.place(context, '${place['area']}')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardHeight;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, keyboardHeight + 12),
        child: SizedBox(
          height: availableHeight * .68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguage.text(
                  context,
                  'Choose a place in {city}',
                ).replaceAll('{city}', AppLanguage.place(context, widget.city)),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: AppLanguage.text(context, 'Search listed places'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text(
                          AppLanguage.text(
                            context,
                            'No listed place matches. Try another name.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: matches.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = matches[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: taxiYellow,
                              child: Icon(
                                Icons.location_on_rounded,
                                color: ink,
                              ),
                            ),
                            title: Text(
                              AppLanguage.place(context, '${place['name']}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              AppLanguage.place(context, '${place['area']}'),
                            ),
                            onTap: () => Navigator.pop(context, place),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                AppLanguage.text(
                  context,
                  'Pilot locations are editable in the backend.',
                ),
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderIllustration extends StatelessWidget {
  const HeaderIllustration({super.key, required this.city});
  final String city;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      width: double.infinity,
      height: 155,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/yangon-taxi-banner.jpg', fit: BoxFit.cover),
          const ColoredBox(color: Color(0x25053F8E)),
          Positioned(
            left: 18,
            top: 20,
            child: Text(
              AppLanguage.text(context, 'GO ANYWHERE\nHAVE A GOOD DAY'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Color(0xFF0A447F), blurRadius: 8)],
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 16,
            child: Text(
              AppLanguage.text(context, '{city} PILOT · CASH RIDES').replaceAll(
                '{city}',
                AppLanguage.place(context, city).toUpperCase(),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Color(0xFF0A447F), blurRadius: 7)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
