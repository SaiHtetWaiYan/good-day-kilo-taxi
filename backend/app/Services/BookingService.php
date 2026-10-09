<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\BookingOffer;
use App\Models\DriverProfile;
use App\Models\FareSetting;
use App\Models\Quote;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class BookingService
{
    public function __construct(private readonly PushNotificationService $push) {}

    public function create(User $passenger, string $quoteId): Booking
    {
        $this->expireSearches();

        $booking = DB::transaction(function () use ($passenger, $quoteId) {
            $quote = Quote::whereKey($quoteId)->lockForUpdate()->firstOrFail();
            abort_unless($quote->passenger_id === $passenger->id, 403);
            abort_if($quote->expires_at->isPast(), 409, 'Quote expired. Request a new fare.');
            abort_if(Booking::where('quote_id', $quote->id)->exists(), 409, 'Quote was already booked.');
            abort_if(Booking::where('passenger_id', $passenger->id)->whereIn('status', ['searching', 'accepted', 'started'])->exists(), 409, 'You already have an active booking.');

            $radius = FareSetting::where('city', config('taxi.city'))->firstOrFail()->search_radius_km;
            $drivers = DriverProfile::query()
                ->where('approval_status', 'approved')
                ->where('is_available', true)
                ->where('location_updated_at', '>=', now()->subSeconds(config('taxi.location_fresh_seconds')))
                ->whereNotNull('latitude')
                ->whereDoesntHave('userActiveBookings')
                ->get()
                ->filter(fn ($profile) => $this->distanceKm((float) $quote->pickup_latitude, (float) $quote->pickup_longitude, (float) $profile->latitude, (float) $profile->longitude) <= $radius)
                ->sortBy(fn ($profile) => $this->distanceKm((float) $quote->pickup_latitude, (float) $quote->pickup_longitude, (float) $profile->latitude, (float) $profile->longitude))
                ->take(20);
            abort_if($drivers->isEmpty(), 409, 'No available drivers nearby. Please try again shortly.');

            $booking = Booking::create(['passenger_id' => $passenger->id, 'quote_id' => $quote->id, 'status' => 'searching']);
            foreach ($drivers as $driver) {
                BookingOffer::create(['booking_id' => $booking->id, 'driver_id' => $driver->user_id, 'status' => 'pending']);
            }

            return $booking;
        });
        $driverIds = $booking->offers()->pluck('driver_id');
        $this->push->sendToUsers(
            $driverIds,
            'New ride request',
            $booking->quote->pickup_label.' → '.$booking->quote->destination_label,
            ['type' => 'booking_offer', 'booking_id' => $booking->id, 'status' => 'searching'],
        );

        return $booking;
    }

    public function expireSearches(): void
    {
        Booking::where('status', 'searching')->where('created_at', '<=', now()->subMinutes(2))
            ->update(['status' => 'unfulfilled', 'updated_at' => now()]);
        BookingOffer::where('status', 'pending')
            ->whereHas('booking', fn ($q) => $q->where('status', 'unfulfilled'))
            ->update(['status' => 'expired', 'updated_at' => now()]);
    }

    public function accept(User $driver, Booking $booking): Booking
    {
        $booking = DB::transaction(function () use ($driver, $booking) {
            $booking = Booking::whereKey($booking->id)->lockForUpdate()->firstOrFail();
            abort_unless($booking->status === 'searching', 409, 'This booking is no longer available.');
            $offer = BookingOffer::where('booking_id', $booking->id)->where('driver_id', $driver->id)->where('status', 'pending')->first();
            abort_unless($offer && $offer->created_at->gt(now()->subMinutes(2)), 403, 'No active offer for this driver.');
            $profile = DriverProfile::where('user_id', $driver->id)->lockForUpdate()->firstOrFail();
            abort_unless($profile->approval_status === 'approved', 403, 'Your driver account is not approved.');
            abort_unless($profile->is_available, 409, 'Go online before accepting.');
            abort_unless($profile->location_updated_at?->gt(now()->subSeconds(config('taxi.location_fresh_seconds'))), 409, 'Update your location before accepting.');
            abort_if(Booking::where('driver_id', $driver->id)->whereIn('status', ['accepted', 'started'])->exists(), 409, 'You already have an active ride.');
            $booking->update([
                'driver_id' => $driver->id,
                'status' => 'accepted',
                'accepted_at' => now(),
            ]);
            $profile->update(['is_available' => false]);
            BookingOffer::where('booking_id', $booking->id)->where('id', '!=', $offer->id)->update(['status' => 'expired']);
            $offer->update(['status' => 'accepted']);

            return $booking;
        });
        $this->push->sendToUsers(
            [$booking->passenger_id],
            'Driver accepted your ride',
            $driver->name.' is on the way.',
            ['type' => 'booking_status', 'booking_id' => $booking->id, 'status' => 'accepted'],
        );

        return $booking;
    }

    public function transition(User $actor, Booking $booking, string $action): Booking
    {
        $booking = DB::transaction(function () use ($actor, $booking, $action) {
            $booking = Booking::whereKey($booking->id)->lockForUpdate()->firstOrFail();
            if ($action === 'cancel') {
                abort_unless($actor->id === $booking->passenger_id && in_array($booking->status, ['searching', 'accepted']), 403);
                $booking->update(['status' => 'cancelled', 'cancelled_at' => now()]);
                BookingOffer::where('booking_id', $booking->id)->where('status', 'pending')->update(['status' => 'expired']);
                if ($booking->driver_id) {
                    DriverProfile::where('user_id', $booking->driver_id)->update(['is_available' => true]);
                }
            } elseif ($action === 'start') {
                abort_unless($actor->id === $booking->driver_id && $booking->status === 'accepted', 403);
                $booking->update(['status' => 'started', 'started_at' => now()]);
            } elseif ($action === 'complete') {
                abort_unless($actor->id === $booking->driver_id && $booking->status === 'started', 403);
                $booking->update(['status' => 'completed', 'completed_at' => now()]);
                DriverProfile::where('user_id', $actor->id)->update(['is_available' => true]);
            }

            return $booking;
        });
        if ($booking->status === 'cancelled' && $booking->driver_id) {
            $this->push->sendToUsers(
                [$booking->driver_id],
                'Ride cancelled',
                'The passenger cancelled this ride.',
                ['type' => 'booking_status', 'booking_id' => $booking->id, 'status' => 'cancelled'],
            );
        } elseif ($booking->status === 'started') {
            $this->push->sendToUsers(
                [$booking->passenger_id],
                'Your ride has started',
                'Have a safe trip with Good Day Kilo Taxi.',
                ['type' => 'booking_status', 'booking_id' => $booking->id, 'status' => 'started'],
            );
        } elseif ($booking->status === 'completed') {
            $this->push->sendToUsers(
                [$booking->passenger_id],
                'Ride completed',
                'Thank you for riding with Good Day Kilo Taxi.',
                ['type' => 'booking_status', 'booking_id' => $booking->id, 'status' => 'completed'],
            );
        }

        return $booking;
    }

    private function distanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $a = sin(deg2rad($lat2 - $lat1) / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin(deg2rad($lon2 - $lon1) / 2) ** 2;

        return 6371 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
