<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PlaceCatalog;

class PlaceController extends Controller
{
    public function index(PlaceCatalog $places)
    {
        return ['city' => config('taxi.city'), 'places' => $places->all()];
    }
}
