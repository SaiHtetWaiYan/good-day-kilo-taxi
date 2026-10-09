<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->string('pickup_pin', 4)->nullable();
        });

        DB::table('bookings')->where('status', 'accepted')->orderBy('id')->eachById(function ($booking) {
            DB::table('bookings')->where('id', $booking->id)->update([
                'pickup_pin' => (string) random_int(1000, 9999),
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropColumn('pickup_pin');
        });
    }
};
