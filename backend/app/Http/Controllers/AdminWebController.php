<?php

namespace App\Http\Controllers;

use App\Models\Booking;
use App\Models\BookingOffer;
use App\Models\DriverProfile;
use App\Models\FareSetting;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class AdminWebController extends Controller
{
    public function login(): View
    {
        return view('admin.login');
    }

    public function authenticate(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            return back()->withErrors(['email' => 'The email or password is incorrect.'])->onlyInput('email');
        }

        if ($request->user()->role !== 'admin') {
            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return back()->withErrors(['email' => 'This account cannot access the admin dashboard.'])->onlyInput('email');
        }

        $request->session()->regenerate();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function dashboard(Request $request): View
    {
        $this->ensureAdmin($request);

        $bookings = Booking::with(['quote', 'passenger:id,name,phone', 'driver:id,name,phone'])
            ->latest('id')
            ->paginate(20);
        $drivers = DriverProfile::with('user:id,name,email,phone')
            ->withCount('userActiveBookings')
            ->withCount('ratings')
            ->withAvg('ratings', 'rating')
            ->latest('location_updated_at')
            ->get();
        $fare = FareSetting::where('city', config('taxi.city'))->firstOrFail();

        return view('admin.dashboard', [
            'bookings' => $bookings,
            'drivers' => $drivers,
            'fare' => $fare,
            'metrics' => [
                'rides_today' => Booking::whereDate('created_at', today())->count(),
                'active_rides' => Booking::whereIn('status', ['searching', 'accepted', 'started'])->count(),
                'completed_rides' => Booking::where('status', 'completed')->count(),
                'online_drivers' => DriverProfile::where('is_available', true)
                    ->where('location_updated_at', '>=', now()->subMinutes(2))->count(),
            ],
        ]);
    }

    public function updateFare(Request $request): RedirectResponse
    {
        $this->ensureAdmin($request);
        $data = $request->validate([
            'base_fare_minor' => ['required', 'integer', 'min:0', 'max:100000000'],
            'per_km_minor' => ['required', 'integer', 'min:0', 'max:100000000'],
            'search_radius_km' => ['required', 'integer', 'min:1', 'max:50'],
        ]);

        FareSetting::where('city', config('taxi.city'))->firstOrFail()->update($data);

        return back()->with('success', 'Fare settings updated. New quotes will use these prices.');
    }

    public function updateDriverApproval(Request $request, DriverProfile $driverProfile): RedirectResponse
    {
        $this->ensureAdmin($request);
        $data = $request->validate(['approval_status' => ['required', 'in:approved,rejected']]);

        if ($data['approval_status'] === 'rejected' && $driverProfile->userActiveBookings()->exists()) {
            return back()->withErrors(['driver' => 'A driver on an active ride cannot be rejected.']);
        }

        $driverProfile->update([
            'approval_status' => $data['approval_status'],
            'is_available' => false,
        ]);
        if ($data['approval_status'] === 'rejected') {
            BookingOffer::where('driver_id', $driverProfile->user_id)
                ->where('status', 'pending')
                ->update(['status' => 'expired']);
        }

        return back()->with('success', "Driver {$driverProfile->user->name} is now {$data['approval_status']}.");
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }

    private function ensureAdmin(Request $request): void
    {
        abort_unless($request->user()?->role === 'admin', 403);
    }
}
