<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingOffer;
use App\Models\DriverProfile;
use App\Models\FareSetting;
use App\Services\BookingPresenter;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    public function bookings(Request $request, BookingPresenter $presenter)
    {
        abort_unless($request->user()->role === 'admin', 403);

        return Booking::latest('id')->paginate(20)->through(fn ($booking) => $presenter->present($booking, $request->user()));
    }

    public function drivers(Request $request)
    {
        abort_unless($request->user()->role === 'admin', 403);

        return DriverProfile::with('user:id,name,email')->get();
    }

    public function updateFare(Request $request)
    {
        abort_unless($request->user()->role === 'admin', 403);
        $data = $request->validate([
            'base_fare_minor' => 'required|integer|min:0|max:100000000',
            'per_km_minor' => 'required|integer|min:0|max:100000000',
            'search_radius_km' => 'required|integer|min:1|max:50',
        ]);
        $fare = FareSetting::where('city', config('taxi.city'))->firstOrFail();
        $fare->update($data);

        return $fare;
    }

    public function updateDriverApproval(Request $request, DriverProfile $driverProfile)
    {
        abort_unless($request->user()->role === 'admin', 403);
        $data = $request->validate(['approval_status' => 'required|in:approved,rejected']);
        abort_if(
            $data['approval_status'] === 'rejected' && $driverProfile->userActiveBookings()->exists(),
            409,
            'A driver on an active ride cannot be rejected.',
        );

        $driverProfile->update([
            'approval_status' => $data['approval_status'],
            'is_available' => false,
        ]);
        if ($data['approval_status'] === 'rejected') {
            BookingOffer::where('driver_id', $driverProfile->user_id)
                ->where('status', 'pending')
                ->update(['status' => 'expired']);
        }

        return $driverProfile->fresh()->load('user:id,name,email,phone');
    }
}
