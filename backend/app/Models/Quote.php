<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Quote extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['id', 'passenger_id', 'pickup_latitude', 'pickup_longitude', 'pickup_label', 'destination_latitude', 'destination_longitude', 'destination_label', 'distance_meters', 'fare_minor', 'route_geometry', 'expires_at'];

    protected function casts(): array
    {
        return ['route_geometry' => 'array', 'expires_at' => 'datetime'];
    }
}
