<?php

use App\Http\Controllers\AdminWebController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::middleware('guest')->group(function () {
    Route::get('/admin/login', [AdminWebController::class, 'login'])->name('login');
    Route::post('/admin/login', [AdminWebController::class, 'authenticate'])
        ->middleware('throttle:10,1')
        ->name('admin.authenticate');
});

Route::middleware('auth')->prefix('admin')->name('admin.')->group(function () {
    Route::get('/', [AdminWebController::class, 'dashboard'])->name('dashboard');
    Route::put('/fare', [AdminWebController::class, 'updateFare'])->name('fare.update');
    Route::put('/drivers/{driverProfile}/approval', [AdminWebController::class, 'updateDriverApproval'])->name('drivers.approval');
    Route::post('/logout', [AdminWebController::class, 'logout'])->name('logout');
});
