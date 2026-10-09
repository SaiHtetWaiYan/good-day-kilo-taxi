<?php

use App\Models\User;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('taxi:make-admin {email}', function (string $email) {
    $user = User::where('email', $email)->firstOrFail();
    $user->update(['role' => 'admin']);
    $this->info("{$user->email} is now an admin.");
})->purpose('Promote an existing account to taxi admin');
