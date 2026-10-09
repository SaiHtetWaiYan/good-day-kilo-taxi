<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AccountController extends Controller
{
    public function update(Request $request)
    {
        $user = $request->user();
        $request->merge(['phone' => preg_replace('/[ -]/', '', (string) $request->input('phone'))]);
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
            'phone' => ['required', 'string', 'max:24', Rule::unique('users')->ignore($user->id), 'regex:/^\+?[0-9][0-9 -]{6,22}$/'],
            'current_password' => ['required_with:password', 'nullable', 'string'],
            'password' => ['nullable', 'string', 'min:8', 'confirmed'],
        ]);

        if (! empty($data['password']) && ! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => 'The current password is incorrect.',
            ]);
        }

        $user->update([
            'name' => $data['name'],
            'phone' => $data['phone'],
            ...(! empty($data['password']) ? ['password' => $data['password']] : []),
        ]);

        return ['user' => $user->only(['id', 'name', 'email', 'phone', 'role'])];
    }
}
