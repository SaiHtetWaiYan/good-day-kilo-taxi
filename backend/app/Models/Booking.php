<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Booking extends Model
{
    protected $fillable = ['passenger_id', 'driver_id', 'quote_id', 'status', 'accepted_at', 'started_at', 'completed_at', 'cancelled_at'];

    public function quote()
    {
        return $this->belongsTo(Quote::class);
    }

    public function passenger()
    {
        return $this->belongsTo(User::class, 'passenger_id');
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function offers()
    {
        return $this->hasMany(BookingOffer::class);
    }

    public function rating()
    {
        return $this->hasOne(RideRating::class);
    }
}
