<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BookingOffer extends Model
{
    protected $fillable = ['booking_id', 'driver_id', 'status'];

    public function booking()
    {
        return $this->belongsTo(Booking::class);
    }
}
