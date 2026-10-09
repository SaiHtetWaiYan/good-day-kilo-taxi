<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->string('role', 16)->default('passenger')->index());

        Schema::create('driver_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('vehicle_plate', 32);
            $table->boolean('is_available')->default(false);
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->timestamp('location_updated_at')->nullable();
            $table->timestamps();
        });

        Schema::create('fare_settings', function (Blueprint $table) {
            $table->id();
            $table->string('city')->unique();
            $table->string('currency', 3);
            $table->unsignedInteger('base_fare_minor');
            $table->unsignedInteger('per_km_minor');
            $table->unsignedSmallInteger('search_radius_km')->default(8);
            $table->timestamps();
        });

        Schema::create('quotes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('passenger_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('pickup_latitude', 10, 7);
            $table->decimal('pickup_longitude', 10, 7);
            $table->decimal('destination_latitude', 10, 7);
            $table->decimal('destination_longitude', 10, 7);
            $table->unsignedInteger('distance_meters');
            $table->unsignedInteger('fare_minor');
            $table->json('route_geometry');
            $table->timestamp('expires_at');
            $table->timestamps();
        });

        Schema::create('bookings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('passenger_id')->constrained('users');
            $table->foreignId('driver_id')->nullable()->constrained('users');
            $table->foreignUuid('quote_id')->unique()->constrained('quotes');
            $table->string('status', 16)->default('searching')->index();
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();
            $table->index(['passenger_id', 'status']);
            $table->index(['driver_id', 'status']);
        });

        Schema::create('booking_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('booking_id')->constrained()->cascadeOnDelete();
            $table->foreignId('driver_id')->constrained('users');
            $table->string('status', 16)->default('pending');
            $table->timestamps();
            $table->unique(['booking_id', 'driver_id']);
            $table->index(['driver_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('booking_offers');
        Schema::dropIfExists('bookings');
        Schema::dropIfExists('quotes');
        Schema::dropIfExists('fare_settings');
        Schema::dropIfExists('driver_profiles');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('role'));
    }
};
