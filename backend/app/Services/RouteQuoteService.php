<?php

namespace App\Services;

use App\Models\FareSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

class RouteQuoteService
{
    public function quote(array $pickup, array $destination): array
    {
        $bounds = config('taxi.city_bounds');
        foreach ([$pickup, $destination] as $point) {
            if ($point['latitude'] < $bounds['south'] || $point['latitude'] > $bounds['north'] ||
                $point['longitude'] < $bounds['west'] || $point['longitude'] > $bounds['east']) {
                throw ValidationException::withMessages(['location' => 'Pickup and destination must be inside the service city.']);
            }
        }

        $coordinates = implode(';', [
            $pickup['longitude'].','.$pickup['latitude'],
            $destination['longitude'].','.$destination['latitude'],
        ]);
        $url = rtrim(config('taxi.routing_url'), '/').'/route/v1/driving/'.$coordinates;
        try {
            $response = Http::timeout(8)->get($url, ['overview' => 'full', 'geometries' => 'geojson']);
        } catch (\Throwable $e) {
            throw ValidationException::withMessages(['route' => 'Could not calculate a road route. Please try again.']);
        }
        $route = $response->json('routes.0');
        if (! $response->ok() || $response->json('code') !== 'Ok' || ! is_array($route) ||
            ! isset($route['distance'], $route['geometry']['coordinates'])) {
            throw ValidationException::withMessages(['route' => 'Could not calculate a road route. Please choose other points.']);
        }

        $settings = FareSetting::where('city', config('taxi.city'))->firstOrFail();
        $meters = (int) round($route['distance']);
        if ($meters < 50) {
            throw ValidationException::withMessages(['route' => 'Choose a destination farther from pickup.']);
        }

        return [
            'distance_meters' => $meters,
            'fare_minor' => (int) ($settings->base_fare_minor + ceil($meters / 1000 * $settings->per_km_minor)),
            'currency' => $settings->currency,
            'route_geometry' => $route['geometry'],
        ];
    }
}
