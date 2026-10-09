<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BookingOffer;
use App\Services\BookingPresenter;
use App\Services\BookingService;
use Illuminate\Http\Request;

class StreamController extends Controller
{
    public function __invoke(Request $request, BookingPresenter $presenter, BookingService $service)
    {
        $user = $request->user();

        return response()->stream(function () use ($user, $presenter, $service) {
            $last = null;
            for ($i = 0; $i < 25 && ! connection_aborted(); $i++) {
                $service->expireSearches();
                if ($user->role === 'driver') {
                    $profile = $user->driverProfile()->first();
                    $active = Booking::where('driver_id', $user->id)->whereIn('status', ['accepted', 'started'])->latest('id')->first();
                    $offers = BookingOffer::with('booking.quote')->where('driver_id', $user->id)->where('status', 'pending')
                        ->where('created_at', '>=', now()->subMinutes(2))
                        ->whereHas('booking', fn ($q) => $q->where('status', 'searching'))->latest('id')->get();
                    $snapshot = ['booking' => $active ? $presenter->present($active, $user) : null,
                        'driver_online' => (bool) $profile?->is_available,
                        'driver_approval_status' => $profile?->approval_status,
                        'offers' => $offers->map(fn ($offer) => $presenter->present($offer->booking, $user))->values()->all()];
                } else {
                    $booking = Booking::where('passenger_id', $user->id)->latest('id')->first();
                    $snapshot = ['booking' => $booking ? $presenter->present($booking, $user) : null];
                }
                $json = json_encode($snapshot);
                if ($json !== $last) {
                    echo "event: snapshot\ndata: {$json}\n\n";
                    $last = $json;
                } else {
                    echo ": keepalive\n\n";
                }
                @ob_flush();
                flush();
                sleep(2);
            }
        }, 200, ['Content-Type' => 'text/event-stream', 'Cache-Control' => 'no-cache', 'X-Accel-Buffering' => 'no']);
    }
}
