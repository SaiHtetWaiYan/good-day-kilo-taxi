<?php

namespace App\Services;

use App\Models\Booking;
use App\Models\FareSetting;
use App\Models\User;

class BookingPresenter
{
    public function present(Booking $booking, ?User $viewer = null): array
    {
        $booking->loadMissing(['quote', 'driver.driverProfile', 'passenger', 'rating']);
        $quote = $booking->quote;

        return [
            'id' => $booking->id,
            'status' => $booking->status,
            'distance_meters' => $quote->distance_meters,
            'fare_minor' => $quote->fare_minor,
            'currency' => FareSetting::where('city', config('taxi.city'))->firstOrFail()->currency,
            'pickup' => ['latitude' => (float) $quote->pickup_latitude, 'longitude' => (float) $quote->pickup_longitude, 'label' => $quote->pickup_label],
            'destination' => ['latitude' => (float) $quote->destination_latitude, 'longitude' => (float) $quote->destination_longitude, 'label' => $quote->destination_label],
            'route_geometry' => $quote->route_geometry,
            'driver' => $booking->driver ? [
                'name' => $booking->driver->name,
                'phone' => $booking->driver->phone,
                'vehicle_plate' => $booking->driver->driverProfile?->vehicle_plate,
                'latitude' => $booking->driver->driverProfile?->latitude ? (float) $booking->driver->driverProfile->latitude : null,
                'longitude' => $booking->driver->driverProfile?->longitude ? (float) $booking->driver->driverProfile->longitude : null,
                'location_updated_at' => $booking->driver->driverProfile?->location_updated_at?->toIso8601String(),
                'distance_to_pickup_meters' => $this->driverDistanceToPickup($booking),
            ] : null,
            'passenger' => $booking->driver_id ? [
                'name' => $booking->passenger->name,
                'phone' => $booking->passenger->phone,
            ] : null,
            'rating' => $booking->rating ? [
                'score' => $booking->rating->rating,
                'comment' => $booking->rating->comment,
            ] : null,
            'created_at' => $booking->created_at?->toIso8601String(),
        ];
    }

    private function driverDistanceToPickup(Booking $booking): ?int
    {
        $profile = $booking->driver?->driverProfile;
        if (! $profile?->latitude || ! $profile?->longitude) {
            return null;
        }

        $lat1 = deg2rad((float) $profile->latitude);
        $lat2 = deg2rad((float) $booking->quote->pickup_latitude);
        $latDelta = $lat2 - $lat1;
        $lonDelta = deg2rad((float) $booking->quote->pickup_longitude - (float) $profile->longitude);
        $a = sin($latDelta / 2) ** 2 + cos($lat1) * cos($lat2) * sin($lonDelta / 2) ** 2;

        return (int) round(6371000 * 2 * atan2(sqrt($a), sqrt(1 - $a)));
    }
}
