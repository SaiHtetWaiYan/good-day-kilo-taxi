<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverProfile extends Model
{
    protected $fillable = ['user_id', 'vehicle_plate', 'approval_status', 'is_available', 'latitude', 'longitude', 'location_updated_at'];

    protected function casts(): array
    {
        return ['is_available' => 'boolean', 'location_updated_at' => 'datetime'];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function userActiveBookings()
    {
        return $this->hasMany(Booking::class, 'driver_id', 'user_id')->whereIn('status', ['accepted', 'started']);
    }

    public function ratings()
    {
        return $this->hasMany(RideRating::class, 'driver_id', 'user_id');
    }
}
