<?php

namespace App\Services;

use App\Models\DeviceToken;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    private ?array $credentials = null;

    public function configured(): bool
    {
        $credentials = $this->credentials();

        return filled($credentials['project_id'] ?? null)
            && filled($credentials['client_email'] ?? null)
            && filled($credentials['private_key'] ?? null);
    }

    public function sendToUsers(iterable $userIds, string $title, string $body, array $data = []): void
    {
        if (! $this->configured()) {
            return;
        }

        $ids = collect($userIds)->filter()->unique()->values();
        if ($ids->isEmpty()) {
            return;
        }

        $tokens = DeviceToken::whereIn('user_id', $ids)
            ->where('last_seen_at', '>=', now()->subDays(90))->get();
        $this->sendTokens($tokens, $title, $body, $data);
    }

    private function sendTokens(Collection $tokens, string $title, string $body, array $data): void
    {
        try {
            $accessToken = $this->accessToken();
            $project = $this->credentials()['project_id'];
            foreach ($tokens as $device) {
                $response = Http::withToken($accessToken)->acceptJson()->timeout(8)
                    ->post("https://fcm.googleapis.com/v1/projects/{$project}/messages:send", [
                        'message' => [
                            'token' => $device->token,
                            'notification' => ['title' => $title, 'body' => $body],
                            'data' => collect($data)->map(fn ($value) => (string) $value)->all(),
                            'android' => [
                                'priority' => 'high',
                                'notification' => [
                                    'channel_id' => 'taxi_bookings',
                                    'sound' => 'default',
                                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                                ],
                            ],
                        ],
                    ]);
                if ($response->successful()) {
                    continue;
                }
                $status = $response->json('error.status');
                if (in_array($status, ['NOT_FOUND', 'UNREGISTERED'])) {
                    $device->delete();
                } else {
                    Log::warning('FCM delivery failed', ['status' => $response->status(), 'error' => $status]);
                }
            }
        } catch (\Throwable $error) {
            Log::warning('FCM delivery exception', ['message' => $error->getMessage()]);
        }
    }

    private function accessToken(): string
    {
        return Cache::remember('firebase:access-token', now()->addMinutes(50), function () {
            $credentials = $this->credentials();
            $now = time();
            $header = $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $this->base64Url(json_encode([
                'iss' => $credentials['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            $unsigned = "{$header}.{$claims}";
            $key = str_replace('\\n', "\n", $credentials['private_key']);
            $signed = openssl_sign($unsigned, $signature, $key, OPENSSL_ALGO_SHA256);
            if (! $signed) {
                throw new \RuntimeException('Could not sign Firebase service account request.');
            }
            $jwt = $unsigned.'.'.$this->base64Url($signature);
            $response = Http::asForm()->timeout(8)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ])->throw();

            return $response->json('access_token');
        });
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function credentials(): array
    {
        if ($this->credentials !== null) {
            return $this->credentials;
        }

        $path = config('services.firebase.credentials');
        if (filled($path) && is_readable($path)) {
            $decoded = json_decode(file_get_contents($path), true);
            if (is_array($decoded)) {
                return $this->credentials = $decoded;
            }
        }

        return $this->credentials = [
            'project_id' => config('services.firebase.project_id'),
            'client_email' => config('services.firebase.client_email'),
            'private_key' => config('services.firebase.private_key'),
        ];
    }
}
