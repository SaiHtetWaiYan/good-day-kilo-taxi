<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FareSetting;
use App\Models\Quote;
use App\Services\PlaceCatalog;
use App\Services\RouteQuoteService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class QuoteController extends Controller
{
    public function store(Request $request, RouteQuoteService $routes, PlaceCatalog $places)
    {
        abort_unless($request->user()->role === 'passenger', 403);
        $data = $request->validate([
            'pickup' => 'required|array',
            'pickup.place_id' => 'nullable|string|max:80',
            'pickup.latitude' => 'nullable|numeric|between:-90,90',
            'pickup.longitude' => 'nullable|numeric|between:-180,180',
            'pickup.label' => 'nullable|string|max:120',
            'destination' => 'required|array',
            'destination.place_id' => 'nullable|string|max:80',
            'destination.latitude' => 'nullable|numeric|between:-90,90',
            'destination.longitude' => 'nullable|numeric|between:-180,180',
            'destination.label' => 'nullable|string|max:120',
        ]);
        $pickup = $places->resolve($data['pickup']);
        $destination = $places->resolve($data['destination']);
        $result = $routes->quote($pickup, $destination);
        $quote = Quote::create([
            'id' => (string) Str::uuid(),
            'passenger_id' => $request->user()->id,
            'pickup_latitude' => $pickup['latitude'],
            'pickup_longitude' => $pickup['longitude'],
            'pickup_label' => $pickup['label'],
            'destination_latitude' => $destination['latitude'],
            'destination_longitude' => $destination['longitude'],
            'destination_label' => $destination['label'],
            'distance_meters' => $result['distance_meters'],
            'fare_minor' => $result['fare_minor'],
            'route_geometry' => $result['route_geometry'],
            'expires_at' => now()->addMinutes(10),
        ]);

        return response()->json([
            'quote_id' => $quote->id,
            'distance_meters' => $quote->distance_meters,
            'fare_minor' => $quote->fare_minor,
            'currency' => $result['currency'],
            'pickup' => $pickup,
            'destination' => $destination,
            'route_geometry' => $quote->route_geometry,
            'expires_at' => $quote->expires_at->toIso8601String(),
        ], 201);
    }

    public function settings()
    {
        $fare = FareSetting::where('city', config('taxi.city'))->firstOrFail();

        return ['city' => $fare->city, 'currency' => $fare->currency, 'base_fare_minor' => $fare->base_fare_minor, 'per_km_minor' => $fare->per_km_minor, 'city_bounds' => config('taxi.city_bounds')];
    }
}
