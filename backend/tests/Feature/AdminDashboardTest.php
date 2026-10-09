<?php

namespace Tests\Feature;

use App\Models\FareSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        FareSetting::create([
            'city' => 'Yangon',
            'currency' => 'MMK',
            'base_fare_minor' => 2000,
            'per_km_minor' => 1000,
            'search_radius_km' => 8,
        ]);
    }

    public function test_guest_is_sent_to_admin_login(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
        $this->get('/admin/login')->assertOk()->assertSee('Operations dashboard');
    }

    public function test_only_admin_account_can_sign_in_to_dashboard(): void
    {
        $passenger = User::factory()->create([
            'email' => 'passenger@example.com',
            'password' => 'password123',
            'role' => 'passenger',
        ]);

        $this->post('/admin/login', [
            'email' => $passenger->email,
            'password' => 'password123',
        ])->assertSessionHasErrors('email');
        $this->assertGuest();

        $admin = User::factory()->create([
            'email' => 'admin@example.com',
            'password' => 'password123',
            'role' => 'admin',
        ]);
        $this->post('/admin/login', [
            'email' => $admin->email,
            'password' => 'password123',
        ])->assertRedirect('/admin');
        $this->assertAuthenticatedAs($admin);
    }

    public function test_admin_can_view_dashboard_and_update_fare(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        $this->actingAs($admin)->get('/admin')
            ->assertOk()
            ->assertSee('Recent bookings')
            ->assertSee('Fare settings');

        $this->actingAs($admin)->put('/admin/fare', [
            'base_fare_minor' => 3000,
            'per_km_minor' => 1200,
            'search_radius_km' => 10,
        ])->assertRedirect()->assertSessionHas('success');

        $this->assertDatabaseHas('fare_settings', [
            'city' => 'Yangon',
            'base_fare_minor' => 3000,
            'per_km_minor' => 1200,
            'search_radius_km' => 10,
        ]);
    }

    public function test_non_admin_session_cannot_open_dashboard(): void
    {
        $passenger = User::factory()->create(['role' => 'passenger']);

        $this->actingAs($passenger)->get('/admin')->assertForbidden();
        $this->actingAs($passenger)->put('/admin/fare', [
            'base_fare_minor' => 3000,
            'per_km_minor' => 1200,
            'search_radius_km' => 10,
        ])->assertForbidden();
    }

    public function test_admin_can_approve_a_pending_driver(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $driver = User::factory()->create(['role' => 'driver']);
        $profile = $driver->driverProfile()->create([
            'vehicle_plate' => 'YGN-9000',
            'approval_status' => 'pending',
        ]);

        $this->actingAs($admin)->get('/admin')
            ->assertOk()
            ->assertSee('YGN-9000')
            ->assertSee('pending');

        $this->actingAs($admin)->put("/admin/drivers/{$profile->id}/approval", [
            'approval_status' => 'approved',
        ])->assertRedirect()->assertSessionHas('success');

        $this->assertDatabaseHas('driver_profiles', [
            'id' => $profile->id,
            'approval_status' => 'approved',
            'is_available' => false,
        ]);
    }
}
