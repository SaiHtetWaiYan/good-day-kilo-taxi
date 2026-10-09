<?php

namespace App\Services;

use Illuminate\Validation\ValidationException;

class PlaceCatalog
{
    public function all(): array
    {
        return config('taxi_places');
    }

    public function resolve(array $selection): array
    {
        if (! empty($selection['place_id'])) {
            $place = collect($this->all())->firstWhere('id', $selection['place_id']);
            if (! $place) {
                throw ValidationException::withMessages(['place_id' => 'Choose a listed pickup or destination.']);
            }

            return [
                'latitude' => $place['latitude'],
                'longitude' => $place['longitude'],
                'label' => $place['name'],
            ];
        }

        if (! isset($selection['latitude'], $selection['longitude'])) {
            throw ValidationException::withMessages(['location' => 'Choose a place or use your current location.']);
        }

        return [
            'latitude' => $selection['latitude'],
            'longitude' => $selection['longitude'],
            'label' => $selection['label'] ?? 'Current location',
        ];
    }
}
