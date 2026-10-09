<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $request->merge(['phone' => preg_replace('/[ -]/', '', (string) $request->input('phone'))]);
        $data = $request->validate([
            'name' => 'required|string|max:80',
            'email' => 'required|email|max:255|unique:users,email',
            'phone' => ['required', 'string', 'max:24', 'unique:users,phone', 'regex:/^\+?[0-9][0-9 -]{6,22}$/'],
            'password' => 'required|string|min:8',
            'role' => 'required|in:passenger,driver',
            'vehicle_plate' => 'required_if:role,driver|nullable|string|max:32',
        ]);
        $user = User::create(collect($data)->only(['name', 'email', 'phone', 'password', 'role'])->all());
        if ($user->role === 'driver') {
            $user->driverProfile()->create(['vehicle_plate' => $data['vehicle_plate']]);
        }

        return response()->json(['token' => $user->createToken('mobile')->plainTextToken, 'user' => $user->only(['id', 'name', 'email', 'phone', 'role'])], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate(['email' => 'required|email', 'password' => 'required|string']);
        $user = User::where('email', $data['email'])->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => 'Invalid credentials.']);
        }

        return ['token' => $user->createToken('mobile')->plainTextToken, 'user' => $user->only(['id', 'name', 'email', 'phone', 'role'])];
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->noContent();
    }
}
