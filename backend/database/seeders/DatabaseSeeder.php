<?php

namespace Database\Seeders;

use App\Models\FareSetting;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        FareSetting::firstOrCreate(['city' => config('taxi.city')], [
            'currency' => 'MMK',
            'base_fare_minor' => 2000,
            'per_km_minor' => 1000,
            'search_radius_km' => 8,
        ]);
    }
}
