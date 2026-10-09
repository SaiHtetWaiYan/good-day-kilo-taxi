<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Operations · Good Day Kilo Taxi</title>
    <style>
        :root { font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #102a43; background: #f3f8fc; }
        * { box-sizing: border-box; }
        body { margin: 0; }
        header { background: linear-gradient(120deg, #007ed8, #0054b8); color: #fff; padding: 16px clamp(18px, 4vw, 52px); display: flex; justify-content: space-between; align-items: center; gap: 20px; }
        .brand { display: flex; align-items: center; gap: 11px; font-weight: 900; font-size: 18px; }
        .brand span { display: grid; place-items: center; background: #ffd51f; color: #123; width: 40px; height: 40px; border-radius: 13px; }
        .user { display: flex; align-items: center; gap: 12px; font-size: 13px; }
        .user button { background: rgba(255,255,255,.14); border: 1px solid rgba(255,255,255,.35); color: #fff; border-radius: 10px; padding: 8px 11px; cursor: pointer; }
        main { width: min(1440px, 100%); margin: auto; padding: 26px clamp(16px, 4vw, 52px) 60px; }
        h1 { font-size: 26px; margin: 0; } h2 { font-size: 18px; margin: 0; }
        .muted { color: #627d98; font-size: 13px; margin-top: 5px; }
        .metrics { display: grid; grid-template-columns: repeat(4, minmax(0,1fr)); gap: 14px; margin: 24px 0; }
        .metric, .panel { background: #fff; border: 1px solid #dfebf3; border-radius: 18px; box-shadow: 0 8px 25px rgba(15, 77, 119, .055); }
        .metric { padding: 18px; } .metric strong { display: block; font-size: 28px; color: #006bc6; margin-top: 6px; }
        .grid { display: grid; grid-template-columns: minmax(0, 2fr) minmax(300px, 1fr); gap: 18px; align-items: start; }
        .panel { overflow: hidden; margin-bottom: 18px; } .panel-head { padding: 18px 20px; border-bottom: 1px solid #e7f0f6; }
        .table-wrap { overflow-x: auto; } table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th { text-align: left; color: #627d98; background: #f8fbfd; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; }
        th, td { padding: 13px 16px; border-bottom: 1px solid #edf2f6; vertical-align: top; } tr:last-child td { border-bottom: 0; }
        .route { min-width: 210px; } .route b { display: block; } .route span { display: block; color: #829ab1; margin-top: 4px; }
        .badge { display: inline-block; border-radius: 999px; padding: 5px 9px; background: #e7f3ff; color: #075d9c; font-weight: 800; font-size: 11px; text-transform: capitalize; }
        .badge.completed { background: #e3f7ee; color: #167251; } .badge.cancelled, .badge.unfulfilled { background: #f4f4f4; color: #627d98; }
        .online { color: #13875b; font-weight: 800; } .offline { color: #829ab1; }
        .approval-actions { display: flex; gap: 6px; margin-top: 7px; }
        .approval-actions button { border: 0; border-radius: 8px; padding: 6px 9px; font: inherit; font-size: 11px; font-weight: 800; cursor: pointer; }
        .approve { background: #def7ec; color: #126c4c; } .reject { background: #fff0f0; color: #9e1b1b; }
        .form { padding: 18px 20px 22px; } .form label { display: block; font-size: 12px; font-weight: 800; margin: 13px 0 6px; }
        .form input { width: 100%; border: 1px solid #c8dce9; border-radius: 11px; padding: 11px; font: inherit; }
        .form button { width: 100%; margin-top: 16px; padding: 12px; border: 0; border-radius: 12px; background: #ffd51f; color: #102a43; font-weight: 900; cursor: pointer; }
        .notice { padding: 13px 16px; border-radius: 13px; background: #def7ec; color: #126c4c; margin: 16px 0; font-size: 13px; font-weight: 700; }
        .errors { background: #fff0f0; color: #9e1b1b; }
        .pagination { padding: 14px 18px; display: flex; justify-content: space-between; color: #627d98; font-size: 12px; }
        .pagination a { color: #006bc6; text-decoration: none; font-weight: 800; }
        @media (max-width: 900px) { .metrics { grid-template-columns: repeat(2,1fr); } .grid { grid-template-columns: 1fr; } }
        @media (max-width: 520px) { .metrics { grid-template-columns: 1fr 1fr; } .user b { display: none; } th,td { padding: 11px 12px; } }
    </style>
</head>
<body>
<header>
    <div class="brand"><span>🚕</span> Good Day Kilo Taxi</div>
    <div class="user"><b>{{ auth()->user()->name }}</b><form method="post" action="{{ route('admin.logout') }}">@csrf<button>Sign out</button></form></div>
</header>
<main>
    <h1>Operations dashboard</h1><div class="muted">Yangon · Cash rides · {{ now()->format('d M Y, H:i') }}</div>
    @if (session('success')) <div class="notice">{{ session('success') }}</div> @endif
    @if ($errors->any()) <div class="notice errors">{{ $errors->first() }}</div> @endif
    <section class="metrics">
        <div class="metric"><span class="muted">Rides today</span><strong>{{ $metrics['rides_today'] }}</strong></div>
        <div class="metric"><span class="muted">Active rides</span><strong>{{ $metrics['active_rides'] }}</strong></div>
        <div class="metric"><span class="muted">Completed total</span><strong>{{ $metrics['completed_rides'] }}</strong></div>
        <div class="metric"><span class="muted">Drivers online</span><strong>{{ $metrics['online_drivers'] }}</strong></div>
    </section>
    <div class="grid">
        <div>
            <section class="panel">
                <div class="panel-head"><h2>Recent bookings</h2><div class="muted">Latest passenger requests and ride status</div></div>
                <div class="table-wrap"><table><thead><tr><th>ID</th><th>Route</th><th>Passenger</th><th>Driver</th><th>Fare</th><th>Status</th></tr></thead><tbody>
                @forelse ($bookings as $booking)
                    <tr><td>#{{ $booking->id }}<br><span class="muted">{{ $booking->created_at->format('d M H:i') }}</span></td>
                    <td class="route"><b>{{ $booking->quote->pickup_label ?? 'Pickup' }}</b><span>to {{ $booking->quote->destination_label ?? 'Destination' }} · {{ number_format($booking->quote->distance_meters / 1000, 1) }} km</span></td>
                    <td>{{ $booking->passenger->name }}<br><span class="muted">{{ $booking->passenger->phone ?: 'No phone' }}</span></td>
                    <td>{{ $booking->driver?->name ?? 'Waiting' }}<br><span class="muted">{{ $booking->driver?->phone }}</span></td>
                    <td><b>Ks {{ number_format($booking->quote->fare_minor) }}</b></td><td><span class="badge {{ $booking->status }}">{{ $booking->status }}</span></td></tr>
                @empty <tr><td colspan="6" class="muted">No bookings yet.</td></tr> @endforelse
                </tbody></table></div>
                @if ($bookings->hasPages()) <div class="pagination"><span>Page {{ $bookings->currentPage() }} of {{ $bookings->lastPage() }}</span><span>@if($bookings->previousPageUrl())<a href="{{ $bookings->previousPageUrl() }}">Previous</a>@endif @if($bookings->nextPageUrl()) · <a href="{{ $bookings->nextPageUrl() }}">Next</a>@endif</span></div> @endif
            </section>
            <section class="panel"><div class="panel-head"><h2>Drivers</h2><div class="muted">Approve new drivers and monitor availability</div></div>
                <div class="table-wrap"><table><thead><tr><th>Driver</th><th>Vehicle</th><th>Rating</th><th>Approval</th><th>Status</th><th>Last location</th></tr></thead><tbody>
                @forelse ($drivers as $driver)
                    @php($isOnline = $driver->is_available && $driver->location_updated_at?->gte(now()->subMinutes(2)))
                    <tr><td><b>{{ $driver->user->name }}</b><br><span class="muted">{{ $driver->user->phone ?: $driver->user->email }}</span></td><td>{{ $driver->vehicle_plate }}</td>
                    <td>@if($driver->ratings_count)<b>⭐ {{ number_format($driver->ratings_avg_rating, 1) }}</b><br><span class="muted">{{ $driver->ratings_count }} {{ Str::plural('rating', $driver->ratings_count) }}</span>@else<span class="muted">No ratings</span>@endif</td>
                    <td><span class="badge {{ $driver->approval_status }}">{{ $driver->approval_status }}</span>
                        <div class="approval-actions">
                            @if($driver->approval_status !== 'approved')<form method="post" action="{{ route('admin.drivers.approval', $driver) }}">@csrf @method('PUT')<input type="hidden" name="approval_status" value="approved"><button class="approve">Approve</button></form>@endif
                            @if($driver->approval_status !== 'rejected' && !$driver->user_active_bookings_count)<form method="post" action="{{ route('admin.drivers.approval', $driver) }}">@csrf @method('PUT')<input type="hidden" name="approval_status" value="rejected"><button class="reject">Reject</button></form>@endif
                        </div>
                    </td><td class="{{ $isOnline ? 'online' : 'offline' }}">{{ $isOnline ? '● Online' : '○ Offline' }}@if($driver->user_active_bookings_count)<br><span class="muted">Active ride</span>@endif</td><td>{{ $driver->location_updated_at?->diffForHumans() ?? 'Never' }}</td></tr>
                @empty <tr><td colspan="6" class="muted">No drivers registered.</td></tr> @endforelse
                </tbody></table></div>
            </section>
        </div>
        <aside class="panel"><div class="panel-head"><h2>Fare settings</h2><div class="muted">Changes apply to new quotes</div></div>
            <form class="form" method="post" action="{{ route('admin.fare.update') }}">@csrf @method('PUT')
                <label for="base">Base fare (Kyats)</label><input id="base" name="base_fare_minor" type="number" min="0" value="{{ old('base_fare_minor', $fare->base_fare_minor) }}" required>
                <label for="perkm">Per kilometer (Kyats)</label><input id="perkm" name="per_km_minor" type="number" min="0" value="{{ old('per_km_minor', $fare->per_km_minor) }}" required>
                <label for="radius">Driver search radius (km)</label><input id="radius" name="search_radius_km" type="number" min="1" max="50" value="{{ old('search_radius_km', $fare->search_radius_km) }}" required>
                <button type="submit">Save fare settings</button>
            </form>
        </aside>
    </div>
</main>
</body>
</html>
