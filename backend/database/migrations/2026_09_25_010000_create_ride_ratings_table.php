<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ride_ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('booking_id')->unique()->constrained()->cascadeOnDelete();
            $table->foreignId('passenger_id')->constrained('users');
            $table->foreignId('driver_id')->constrained('users');
            $table->unsignedTinyInteger('rating');
            $table->string('comment', 500)->nullable();
            $table->timestamps();
            $table->index(['driver_id', 'rating']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ride_ratings');
    }
};
