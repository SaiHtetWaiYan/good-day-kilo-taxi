<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RideRating extends Model
{
    protected $fillable = ['booking_id', 'passenger_id', 'driver_id', 'rating', 'comment'];

    protected function casts(): array
    {
        return ['rating' => 'integer'];
    }

    public function booking()
    {
        return $this->belongsTo(Booking::class);
    }
}
