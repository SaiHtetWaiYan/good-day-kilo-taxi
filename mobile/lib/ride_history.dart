import 'package:flutter/material.dart';

import 'api.dart';
import 'app_language.dart';
import 'app_theme.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key, required this.api});

  final Api api;

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  late Future<List<Map<String, dynamic>>> rides = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.api.get('/bookings');
    return (response['bookings'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  String _t(String value) => AppLanguage.text(context, value);

  String _status(String value) => switch (value) {
    'searching' => _t('Finding your driver'),
    'accepted' => _t('Driver on the way'),
    'started' => _t('Ride in progress'),
    'completed' => _t('Completed'),
    'cancelled' => _t('Cancelled'),
    _ => _t('No driver found'),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t('My rides'))),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: rides,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => rides = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_t('Try again')),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route_rounded, size: 56, color: muted),
                const SizedBox(height: 12),
                Text(
                  _t('No rides yet'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => rides = _load()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _rideCard(items[index]),
          ),
        );
      },
    ),
  );

  Widget _rideCard(Map<String, dynamic> ride) {
    final pickup = ride['pickup'] as Map<String, dynamic>? ?? const {};
    final destination =
        ride['destination'] as Map<String, dynamic>? ?? const {};
    final status = ride['status']?.toString() ?? '';
    final distance = ((ride['distance_meters'] as num? ?? 0) / 1000)
        .toStringAsFixed(1);
    final fare = (ride['fare_minor'] as num? ?? 0).round();
    final created = DateTime.tryParse(
      ride['created_at']?.toString() ?? '',
    )?.toLocal();
    final date = created == null
        ? ''
        : '${created.day}/${created.month}/${created.year}  '
              '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E9F8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? const Color(0xFFE2F6EF)
                      : const Color(0xFFFFF3CF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status(status),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _place(
            Icons.radio_button_checked_rounded,
            pickup['label']?.toString() ?? '',
            taxiBlue,
          ),
          const SizedBox(height: 10),
          _place(
            Icons.flag_rounded,
            destination['label']?.toString() ?? '',
            const Color(0xFFE83A66),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text('$distance km', style: const TextStyle(color: muted)),
              const Spacer(),
              Text(
                'Ks $fare',
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (ride['rating'] is Map<String, dynamic>) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: taxiYellow, size: 20),
                const SizedBox(width: 5),
                Text(
                  '${(ride['rating'] as Map<String, dynamic>)['score']}/5',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ('${(ride['rating'] as Map<String, dynamic>)['comment'] ?? ''}'
                    .isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${(ride['rating'] as Map<String, dynamic>)['comment']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _place(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
