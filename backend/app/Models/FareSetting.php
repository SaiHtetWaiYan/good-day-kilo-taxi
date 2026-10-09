<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FareSetting extends Model
{
    protected $fillable = ['city', 'currency', 'base_fare_minor', 'per_km_minor', 'search_radius_km'];
}
