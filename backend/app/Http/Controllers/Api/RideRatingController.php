<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\RideRating;
use App\Services\BookingPresenter;
use Illuminate\Http\Request;

class RideRatingController extends Controller
{
    public function store(Request $request, Booking $booking, BookingPresenter $presenter)
    {
        $user = $request->user();
        abort_unless($user->role === 'passenger' && $booking->passenger_id === $user->id, 403);
        abort_unless($booking->status === 'completed' && $booking->driver_id, 409, 'Only completed rides can be rated.');
        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:500'],
        ]);

        RideRating::updateOrCreate(
            ['booking_id' => $booking->id],
            [
                'passenger_id' => $user->id,
                'driver_id' => $booking->driver_id,
                'rating' => $data['rating'],
                'comment' => filled($data['comment'] ?? null) ? trim($data['comment']) : null,
            ],
        );

        return $presenter->present($booking->fresh(), $user);
    }
}
