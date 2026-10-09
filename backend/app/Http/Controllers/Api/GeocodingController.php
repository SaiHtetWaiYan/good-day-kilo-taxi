<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GeocodingService;
use Illuminate\Http\Request;

class GeocodingController extends Controller
{
    public function search(Request $request, GeocodingService $geocoding)
    {
        $data = $request->validate(['q' => 'required|string|min:2|max:120']);

        return ['results' => $geocoding->search($data['q'])];
    }

    public function reverse(Request $request, GeocodingService $geocoding)
    {
        $data = $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
        ]);
        $bounds = config('taxi.city_bounds');
        abort_unless(
            $data['latitude'] >= $bounds['south'] && $data['latitude'] <= $bounds['north']
            && $data['longitude'] >= $bounds['west'] && $data['longitude'] <= $bounds['east'],
            422,
            'Location must be inside the service city.'
        );

        return ['place' => $geocoding->reverse((float) $data['latitude'], (float) $data['longitude'])];
    }
}
