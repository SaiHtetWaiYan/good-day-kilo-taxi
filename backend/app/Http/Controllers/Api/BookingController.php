<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingOffer;
use App\Services\BookingPresenter;
use App\Services\BookingService;
use Illuminate\Http\Request;

class BookingController extends Controller
{
    public function index(Request $request, BookingPresenter $presenter)
    {
        $user = $request->user();
        $query = Booking::with(['quote', 'driver.driverProfile'])->latest('id');
        $query->where($user->role === 'driver' ? 'driver_id' : 'passenger_id', $user->id);

        return [
            'bookings' => $query->limit(30)->get()
                ->map(fn (Booking $booking) => $presenter->present($booking, $user))->values(),
        ];
    }

    public function store(Request $request, BookingService $service, BookingPresenter $presenter)
    {
        abort_unless($request->user()->role === 'passenger', 403);
        $data = $request->validate(['quote_id' => 'required|uuid']);

        return response()->json($presenter->present($service->create($request->user(), $data['quote_id']), $request->user()), 201);
    }

    public function show(Request $request, Booking $booking, BookingPresenter $presenter, BookingService $service)
    {
        $service->expireSearches();
        $booking->refresh();
        abort_unless(in_array($request->user()->id, [$booking->passenger_id, $booking->driver_id]) || $request->user()->role === 'admin', 403);

        return $presenter->present($booking, $request->user());
    }

    public function active(Request $request, BookingPresenter $presenter, BookingService $service)
    {
        $service->expireSearches();
        $user = $request->user();
        $query = Booking::whereIn('status', ['searching', 'accepted', 'started']);
        $query->where($user->role === 'driver' ? 'driver_id' : 'passenger_id', $user->id);
        $booking = $query->latest('id')->first();

        return ['booking' => $booking ? $presenter->present($booking, $user) : null];
    }

    public function accept(Request $request, Booking $booking, BookingService $service, BookingPresenter $presenter)
    {
        abort_unless($request->user()->role === 'driver', 403);

        return $presenter->present($service->accept($request->user(), $booking), $request->user());
    }

    public function transition(Request $request, Booking $booking, string $action, BookingService $service, BookingPresenter $presenter)
    {
        abort_unless(in_array($action, ['cancel', 'start', 'complete']), 404);

        return $presenter->present(
            $service->transition($request->user(), $booking, $action),
            $request->user(),
        );
    }

    public function offers(Request $request, BookingPresenter $presenter, BookingService $service)
    {
        $service->expireSearches();
        abort_unless($request->user()->role === 'driver', 403);
        if (! $request->user()->driverProfile?->is_available) {
            return ['offers' => []];
        }
        $offers = BookingOffer::with('booking.quote')
            ->where('driver_id', $request->user()->id)->where('status', 'pending')
            ->where('created_at', '>=', now()->subMinutes(2))
            ->whereHas('booking', fn ($q) => $q->where('status', 'searching'))
            ->latest('id')->get();

        return ['offers' => $offers->map(fn ($offer) => $presenter->present($offer->booking, $request->user()))->values()];
    }
}
