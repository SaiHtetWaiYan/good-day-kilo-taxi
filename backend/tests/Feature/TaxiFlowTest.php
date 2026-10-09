<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\DeviceToken;
use App\Models\FareSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TaxiFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        FareSetting::create(['city' => 'Yangon', 'currency' => 'MMK', 'base_fare_minor' => 2000, 'per_km_minor' => 1000, 'search_radius_km' => 8]);
        Http::fake(['*/route/v1/*' => Http::response([
            'code' => 'Ok',
            'routes' => [['distance' => 3200, 'geometry' => ['type' => 'LineString', 'coordinates' => [[96.1582, 16.7745], [96.1497, 16.7984]]]]],
        ])]);
    }

    public function test_passenger_books_and_first_nearby_driver_accepts(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger', 'phone' => '09111111111']);
        $driverA = $this->driver('A', 16.7750, 96.1585, '09222222222');
        $driverB = $this->driver('B', 16.7760, 96.1590);
        $farDriver = $this->driver('Far', 16.9500, 96.2400);

        Sanctum::actingAs($passenger);
        $this->getJson('/api/places')->assertJsonPath('city', 'Yangon')->assertJsonCount(9, 'places');
        $quote = $this->postJson('/api/quotes', [
            'pickup' => ['place_id' => 'sule'],
            'destination' => ['place_id' => 'shwedagon'],
        ])->assertCreated()->assertJsonPath('fare_minor', 5200)
            ->assertJsonPath('pickup.label', 'Sule Pagoda')->json();
        $booking = $this->postJson('/api/bookings', ['quote_id' => $quote['quote_id']])
            ->assertCreated()->assertJsonPath('status', 'searching')->json();
        $this->postJson('/api/bookings', ['quote_id' => $quote['quote_id']])->assertStatus(409);

        Sanctum::actingAs($farDriver);
        $this->getJson('/api/driver/offers')->assertJsonCount(0, 'offers');
        Sanctum::actingAs($driverB);
        $this->getJson('/api/driver/offers')->assertJsonCount(1, 'offers');
        Sanctum::actingAs($driverA);
        $this->postJson("/api/bookings/{$booking['id']}/accept")->assertOk()
            ->assertJsonPath('driver.name', $driverA->name)
            ->assertJsonPath('driver.phone', '09222222222')
            ->assertJsonPath('passenger.phone', '09111111111')
            ->assertJsonPath('driver.latitude', 16.775)
            ->assertJsonPath('driver.longitude', 96.1585)
            ->assertJsonPath('driver.distance_to_pickup_meters', 64);
        Sanctum::actingAs($driverB);
        $this->postJson("/api/bookings/{$booking['id']}/accept")->assertStatus(409);

        Sanctum::actingAs($passenger);
        $this->getJson("/api/bookings/{$booking['id']}")->assertJsonPath('status', 'accepted')
            ->assertJsonPath('pickup.label', 'Sule Pagoda')
            ->assertJsonPath('driver.vehicle_plate', 'PLATE-A');
        $this->getJson('/api/bookings/active')->assertJsonPath('booking.id', $booking['id']);
        $this->assertSame(1, Booking::count());
    }

    public function test_registration_saves_a_normalized_phone_number(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Phone Passenger',
            'email' => 'phone-passenger@example.com',
            'phone' => '09 777 888 999',
            'password' => 'password123',
            'role' => 'passenger',
        ])->assertCreated()->assertJsonPath('user.phone', '09777888999');

        $this->assertDatabaseHas('users', [
            'email' => 'phone-passenger@example.com',
            'phone' => '09777888999',
        ]);
    }

    public function test_user_can_update_profile_and_change_password(): void
    {
        $user = User::factory()->create([
            'role' => 'passenger',
            'phone' => '09111111111',
            'password' => 'old-password',
        ]);
        Sanctum::actingAs($user);

        $this->putJson('/api/me', [
            'name' => 'Updated Passenger',
            'phone' => '09 222 333 444',
        ])->assertOk()
            ->assertJsonPath('user.name', 'Updated Passenger')
            ->assertJsonPath('user.phone', '09222333444');

        $this->putJson('/api/me', [
            'name' => 'Updated Passenger',
            'phone' => '09222333444',
            'current_password' => 'wrong-password',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');

        $this->putJson('/api/me', [
            'name' => 'Updated Passenger',
            'phone' => '09222333444',
            'current_password' => 'old-password',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertOk();

        $this->assertTrue(Hash::check('new-password', $user->fresh()->password));
    }

    public function test_driver_can_start_and_complete_ride(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        $driver = $this->driver('A', 16.7750, 96.1585);
        Sanctum::actingAs($passenger);
        $quoteId = $this->postJson('/api/quotes', [
            'pickup' => ['latitude' => 16.7745, 'longitude' => 96.1582],
            'destination' => ['latitude' => 16.7984, 'longitude' => 96.1497],
        ])->json('quote_id');
        $id = $this->postJson('/api/bookings', ['quote_id' => $quoteId])->json('id');
        Sanctum::actingAs($driver);
        $this->postJson("/api/bookings/$id/accept")->assertOk();
        $this->postJson("/api/bookings/$id/start")->assertJsonPath('status', 'started');
        $this->postJson("/api/bookings/$id/complete")->assertJsonPath('status', 'completed');
        $this->assertTrue($driver->driverProfile->fresh()->is_available);
        $this->getJson('/api/bookings')->assertOk()
            ->assertJsonCount(1, 'bookings')
            ->assertJsonPath('bookings.0.status', 'completed');

        $this->postJson("/api/bookings/$id/rating", ['rating' => 5])->assertForbidden();
        Sanctum::actingAs($passenger);
        $this->postJson("/api/bookings/$id/rating", [
            'rating' => 5,
            'comment' => 'Safe and friendly driver.',
        ])->assertOk()
            ->assertJsonPath('rating.score', 5)
            ->assertJsonPath('rating.comment', 'Safe and friendly driver.');
        $this->assertDatabaseHas('ride_ratings', [
            'booking_id' => $id,
            'passenger_id' => $passenger->id,
            'driver_id' => $driver->id,
            'rating' => 5,
        ]);
    }

    public function test_active_driver_can_keep_updating_live_location(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        $driver = $this->driver('A', 16.7750, 96.1585);
        Sanctum::actingAs($passenger);
        $quoteId = $this->postJson('/api/quotes', [
            'pickup' => ['latitude' => 16.7745, 'longitude' => 96.1582],
            'destination' => ['latitude' => 16.7984, 'longitude' => 96.1497],
        ])->json('quote_id');
        $id = $this->postJson('/api/bookings', ['quote_id' => $quoteId])->json('id');

        Sanctum::actingAs($driver);
        $this->postJson("/api/bookings/$id/accept")->assertOk();
        $this->putJson('/api/driver/location', [
            'latitude' => 16.7760,
            'longitude' => 96.1590,
            'is_available' => false,
        ])->assertOk()->assertJsonPath('is_available', false);

        Sanctum::actingAs($passenger);
        $this->getJson("/api/bookings/$id")
            ->assertJsonPath('driver.latitude', 16.776)
            ->assertJsonPath('driver.longitude', 96.159)
            ->assertJsonPath('driver.distance_to_pickup_meters', 187);
    }

    public function test_authenticated_user_can_search_and_reverse_geocode_yangon(): void
    {
        Http::fake([
            '*/search*' => Http::response([[
                'place_id' => 123,
                'lat' => '16.7790',
                'lon' => '96.1580',
                'name' => 'Sule Pagoda',
                'display_name' => 'Sule Pagoda, Yangon, Myanmar',
                'address' => ['road' => 'Maha Bandula Road', 'city' => 'Yangon'],
            ]]),
            '*/reverse*' => Http::response([
                'place_id' => 124,
                'lat' => '16.7790',
                'lon' => '96.1580',
                'name' => 'Sule Pagoda',
                'display_name' => 'Sule Pagoda, Yangon, Myanmar',
                'address' => ['road' => 'Maha Bandula Road', 'city' => 'Yangon'],
            ]),
        ]);
        $passenger = User::factory()->create(['role' => 'passenger']);
        Sanctum::actingAs($passenger);

        $this->getJson('/api/geocoding/search?q=Sule')->assertOk()
            ->assertJsonPath('results.0.name', 'Sule Pagoda')
            ->assertJsonPath('results.0.latitude', 16.779);
        $this->getJson('/api/geocoding/reverse?latitude=16.779&longitude=96.158')->assertOk()
            ->assertJsonPath('place.label', 'Sule Pagoda, Yangon, Myanmar');
    }

    public function test_no_driver_or_outside_city_does_not_book(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        Sanctum::actingAs($passenger);
        $this->postJson('/api/quotes', [
            'pickup' => ['place_id' => 'unknown'],
            'destination' => ['place_id' => 'shwedagon'],
        ])->assertUnprocessable();
        $this->postJson('/api/quotes', [
            'pickup' => ['latitude' => 19.0, 'longitude' => 96.15],
            'destination' => ['latitude' => 16.7984, 'longitude' => 96.1497],
        ])->assertUnprocessable();
        $quoteId = $this->postJson('/api/quotes', [
            'pickup' => ['latitude' => 16.7745, 'longitude' => 96.1582],
            'destination' => ['latitude' => 16.7984, 'longitude' => 96.1497],
        ])->json('quote_id');
        $this->postJson('/api/bookings', ['quote_id' => $quoteId])->assertStatus(409);
    }

    public function test_unanswered_request_expires_and_frees_passenger(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        $this->driver('A', 16.7750, 96.1585);
        Sanctum::actingAs($passenger);
        $quoteId = $this->postJson('/api/quotes', [
            'pickup' => ['latitude' => 16.7745, 'longitude' => 96.1582],
            'destination' => ['latitude' => 16.7984, 'longitude' => 96.1497],
        ])->json('quote_id');
        $id = $this->postJson('/api/bookings', ['quote_id' => $quoteId])->json('id');
        $this->travel(3)->minutes();
        $this->getJson("/api/bookings/$id")->assertJsonPath('status', 'unfulfilled');
        $this->assertDatabaseHas('booking_offers', ['booking_id' => $id, 'status' => 'expired']);
        $this->getJson('/api/bookings/active')->assertJsonPath('booking', null);
    }

    public function test_only_admin_can_change_fares(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        Sanctum::actingAs($passenger);
        $this->putJson('/api/admin/fare', ['base_fare_minor' => 20000, 'per_km_minor' => 6000, 'search_radius_km' => 10])->assertForbidden();
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/fare', ['base_fare_minor' => 20000, 'per_km_minor' => 6000, 'search_radius_km' => 10])->assertOk();
        $this->assertSame(20000, FareSetting::first()->base_fare_minor);
    }

    public function test_driver_can_go_offline_without_requesting_location_again(): void
    {
        $driver = $this->driver('A', 16.7750, 96.1585);
        Sanctum::actingAs($driver);
        $this->putJson('/api/driver/location', ['is_available' => false])
            ->assertOk()->assertJsonPath('is_available', false);
        $this->putJson('/api/driver/location', ['is_available' => true])->assertUnprocessable();
        $this->putJson('/api/driver/location', [
            'latitude' => 16.7750, 'longitude' => 96.1585, 'is_available' => true,
        ])->assertOk()->assertJsonPath('is_available', true);
    }

    public function test_new_driver_needs_admin_approval_before_going_online(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'New Driver',
            'email' => 'new-driver@example.com',
            'phone' => '09987654321',
            'password' => 'password123',
            'role' => 'driver',
            'vehicle_plate' => 'YGN-1234',
        ])->assertCreated();
        $driver = User::findOrFail($response->json('user.id'));

        Sanctum::actingAs($driver);
        $this->getJson('/api/driver/status')->assertJsonPath('approval_status', 'pending');
        $this->putJson('/api/driver/location', [
            'latitude' => 16.7750,
            'longitude' => 96.1585,
            'is_available' => true,
        ])->assertForbidden();

        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/drivers/'.$driver->driverProfile->id.'/approval', [
            'approval_status' => 'approved',
        ])->assertOk()->assertJsonPath('approval_status', 'approved');

        Sanctum::actingAs($driver);
        $this->putJson('/api/driver/location', [
            'latitude' => 16.7750,
            'longitude' => 96.1585,
            'is_available' => true,
        ])->assertOk()->assertJsonPath('is_available', true);
    }

    public function test_phone_can_register_refresh_and_remove_its_push_token(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);
        Sanctum::actingAs($passenger);

        $this->postJson('/api/device-tokens', [
            'token' => 'test-fcm-token',
            'platform' => 'android',
        ])->assertCreated()->assertJsonPath('registered', true);
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $passenger->id,
            'token' => 'test-fcm-token',
        ]);

        $this->deleteJson('/api/device-tokens', ['token' => 'test-fcm-token'])
            ->assertNoContent();
        $this->assertSame(0, DeviceToken::count());
    }

    private function driver(string $name, float $lat, float $lon, ?string $phone = null): User
    {
        $driver = User::factory()->create(['name' => $name, 'role' => 'driver', 'phone' => $phone]);
        $driver->driverProfile()->create([
            'vehicle_plate' => "PLATE-$name", 'approval_status' => 'approved', 'is_available' => true,
            'latitude' => $lat, 'longitude' => $lon, 'location_updated_at' => now(),
        ]);

        return $driver;
    }
}
