<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'token' => 'required|string|max:4096',
            'platform' => 'required|in:android,ios',
        ]);
        $token = DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            [
                'user_id' => $request->user()->id,
                'platform' => $data['platform'],
                'last_seen_at' => now(),
            ],
        );

        return response()->json(['registered' => true, 'id' => $token->id], 201);
    }

    public function destroy(Request $request)
    {
        $data = $request->validate(['token' => 'required|string|max:4096']);
        DeviceToken::where('user_id', $request->user()->id)
            ->where('token', $data['token'])->delete();

        return response()->noContent();
    }
}
