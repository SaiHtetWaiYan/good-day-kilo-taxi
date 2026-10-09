<?php

return [
    'city' => env('SERVICE_CITY', 'Yangon'),
    'routing_url' => env('ROUTING_URL', 'https://router.project-osrm.org'),
    'geocoding_url' => env('GEOCODING_URL', 'https://nominatim.openstreetmap.org'),
    'geocoding_contact' => env('GEOCODING_CONTACT', 'support@taxi.saihtet.dev'),
    'city_bounds' => [
        'south' => (float) env('CITY_SOUTH', 16.55),
        'north' => (float) env('CITY_NORTH', 17.20),
        'west' => (float) env('CITY_WEST', 95.85),
        'east' => (float) env('CITY_EAST', 96.50),
    ],
    'location_fresh_seconds' => 120,
];
