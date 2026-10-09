<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingOffer;
use Illuminate\Http\Request;

class DriverController extends Controller
{
    public function status(Request $request)
    {
        abort_unless($request->user()->role === 'driver', 403);
        $profile = $request->user()->driverProfile()->firstOrFail();

        return ['is_available' => $profile->is_available, 'approval_status' => $profile->approval_status, 'latitude' => $profile->latitude ? (float) $profile->latitude : null, 'longitude' => $profile->longitude ? (float) $profile->longitude : null];
    }

    public function updateLocation(Request $request)
    {
        abort_unless($request->user()->role === 'driver', 403);
        $profile = $request->user()->driverProfile()->firstOrFail();
        abort_unless($profile->approval_status === 'approved', 403, 'Your driver account is waiting for admin approval.');
        $data = $request->validate([
            'latitude' => 'required_if:is_available,true|nullable|numeric|between:-90,90',
            'longitude' => 'required_if:is_available,true|nullable|numeric|between:-180,180',
            'is_available' => 'required|boolean',
        ]);
        $bounds = config('taxi.city_bounds');
        if (isset($data['latitude'], $data['longitude'])) {
            abort_unless($data['latitude'] >= $bounds['south'] && $data['latitude'] <= $bounds['north'] && $data['longitude'] >= $bounds['west'] && $data['longitude'] <= $bounds['east'], 422, 'Driver must be inside the service city.');
        }
        $active = Booking::where('driver_id', $request->user()->id)->whereIn('status', ['accepted', 'started'])->exists();
        $profile->update([
            'latitude' => $data['latitude'] ?? $profile->latitude,
            'longitude' => $data['longitude'] ?? $profile->longitude,
            'location_updated_at' => isset($data['latitude'], $data['longitude']) ? now() : $profile->location_updated_at,
            'is_available' => $active ? false : $data['is_available'],
        ]);
        if (! $profile->is_available && ! $active) {
            BookingOffer::where('driver_id', $request->user()->id)->where('status', 'pending')->update(['status' => 'expired']);
        }

        return ['is_available' => $profile->is_available, 'approval_status' => $profile->approval_status, 'latitude' => (float) $profile->latitude, 'longitude' => (float) $profile->longitude];
    }
}
