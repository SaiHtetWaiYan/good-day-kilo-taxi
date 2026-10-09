<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BookingController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\GeocodingController;
use App\Http\Controllers\Api\PlaceController;
use App\Http\Controllers\Api\QuoteController;
use App\Http\Controllers\Api\RideRatingController;
use App\Http\Controllers\Api\StreamController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::get('/settings', [QuoteController::class, 'settings']);
Route::get('/places', [PlaceController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', fn (Request $request) => $request->user()->only(['id', 'name', 'email', 'phone', 'role']));
    Route::put('/me', [AccountController::class, 'update']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/device-tokens', [DeviceTokenController::class, 'store']);
    Route::delete('/device-tokens', [DeviceTokenController::class, 'destroy']);
    Route::post('/quotes', [QuoteController::class, 'store']);
    Route::post('/bookings', [BookingController::class, 'store']);
    Route::get('/bookings/active', [BookingController::class, 'active']);
    Route::get('/bookings', [BookingController::class, 'index']);
    Route::get('/bookings/{booking}', [BookingController::class, 'show']);
    Route::post('/bookings/{booking}/accept', [BookingController::class, 'accept']);
    Route::post('/bookings/{booking}/rating', [RideRatingController::class, 'store']);
    Route::post('/bookings/{booking}/{action}', [BookingController::class, 'transition']);
    Route::get('/driver/offers', [BookingController::class, 'offers']);
    Route::get('/driver/status', [DriverController::class, 'status']);
    Route::put('/driver/location', [DriverController::class, 'updateLocation']);
    Route::get('/stream', StreamController::class);
    Route::middleware('throttle:30,1')->group(function () {
        Route::get('/geocoding/search', [GeocodingController::class, 'search']);
        Route::get('/geocoding/reverse', [GeocodingController::class, 'reverse']);
    });
    Route::get('/admin/bookings', [AdminController::class, 'bookings']);
    Route::get('/admin/drivers', [AdminController::class, 'drivers']);
    Route::put('/admin/drivers/{driverProfile}/approval', [AdminController::class, 'updateDriverApproval']);
    Route::put('/admin/fare', [AdminController::class, 'updateFare']);
});
