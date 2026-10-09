<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class GeocodingService
{
    public function search(string $query): array
    {
        $bounds = config('taxi.city_bounds');
        $key = 'geocode:search:'.sha1(mb_strtolower(trim($query)));

        return Cache::remember($key, now()->addMinutes(15), function () use ($query, $bounds) {
            $response = $this->client()->get(config('taxi.geocoding_url').'/search', [
                'format' => 'jsonv2',
                'q' => trim($query).', '.config('taxi.city').', Myanmar',
                'countrycodes' => 'mm',
                'bounded' => 1,
                'viewbox' => implode(',', [$bounds['west'], $bounds['north'], $bounds['east'], $bounds['south']]),
                'addressdetails' => 1,
                'limit' => 6,
            ])->throw()->json();

            return collect($response)->map(fn (array $place) => $this->present($place))
                ->filter(fn (array $place) => $this->insideBounds($place['latitude'], $place['longitude']))
                ->values()->all();
        });
    }

    public function reverse(float $latitude, float $longitude): array
    {
        $key = sprintf('geocode:reverse:%.5f:%.5f', $latitude, $longitude);

        return Cache::remember($key, now()->addDays(30), function () use ($latitude, $longitude) {
            $place = $this->client()->get(config('taxi.geocoding_url').'/reverse', [
                'format' => 'jsonv2',
                'lat' => $latitude,
                'lon' => $longitude,
                'zoom' => 18,
                'addressdetails' => 1,
            ])->throw()->json();

            return $this->present($place);
        });
    }

    private function client()
    {
        return Http::acceptJson()
            ->withUserAgent(config('app.name').' '.config('app.url').' contact: '.config('taxi.geocoding_contact'))
            ->connectTimeout(4)
            ->timeout(8)
            ->retry(2, 250);
    }

    private function present(array $place): array
    {
        $address = $place['address'] ?? [];
        $primary = $place['name'] ?? $address['road'] ?? $address['suburb'] ?? config('taxi.city');
        $secondaryParts = array_filter([
            $address['road'] ?? null,
            $address['suburb'] ?? $address['quarter'] ?? null,
            $address['town'] ?? $address['city'] ?? config('taxi.city'),
        ], fn ($part) => $part && $part !== $primary);

        return [
            'id' => isset($place['place_id']) ? (string) $place['place_id'] : null,
            'name' => $primary,
            'area' => implode(', ', array_unique($secondaryParts)),
            'label' => $place['display_name'] ?? implode(', ', array_filter([$primary, ...$secondaryParts])),
            'latitude' => (float) ($place['lat'] ?? 0),
            'longitude' => (float) ($place['lon'] ?? 0),
        ];
    }

    private function insideBounds(float $latitude, float $longitude): bool
    {
        $bounds = config('taxi.city_bounds');

        return $latitude >= $bounds['south'] && $latitude <= $bounds['north']
            && $longitude >= $bounds['west'] && $longitude <= $bounds['east'];
    }
}
