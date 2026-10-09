<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin sign in · Good Day Kilo Taxi</title>
    <style>
        :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #102a43; background: #edf7ff; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px; background: radial-gradient(circle at top, #d8f7ff 0, #edf7ff 44%, #fff8d8 100%); }
        main { width: min(100%, 430px); background: #fff; border: 1px solid #dcecf7; border-radius: 26px; padding: 32px; box-shadow: 0 22px 65px rgba(0, 96, 170, .14); }
        .brand { display: flex; align-items: center; gap: 14px; margin-bottom: 30px; }
        .taxi { width: 54px; height: 54px; display: grid; place-items: center; border-radius: 18px; background: #ffd51f; font-size: 28px; }
        h1 { font-size: 22px; margin: 0 0 3px; color: #0069c7; }
        .subtitle { margin: 0; color: #627d98; font-size: 13px; }
        label { display: block; margin: 18px 0 7px; font-weight: 750; font-size: 13px; }
        input[type=email], input[type=password] { width: 100%; border: 1px solid #bfd7e8; border-radius: 13px; padding: 13px 14px; font: inherit; outline: none; }
        input:focus { border-color: #0087eb; box-shadow: 0 0 0 3px rgba(0, 135, 235, .12); }
        .remember { display: flex; gap: 8px; align-items: center; color: #486581; font-size: 13px; margin: 16px 0; }
        button { width: 100%; border: 0; border-radius: 14px; padding: 14px; background: linear-gradient(135deg, #0089ed, #005bc4); color: #fff; font: inherit; font-weight: 800; cursor: pointer; }
        .error { background: #fff0f0; color: #a61b1b; border-radius: 12px; padding: 11px 13px; font-size: 13px; margin: 10px 0; }
        .secure { text-align: center; color: #829ab1; font-size: 11px; margin: 18px 0 0; }
    </style>
</head>
<body>
<main>
    <div class="brand"><div class="taxi">🚕</div><div><h1>Good Day Kilo Taxi</h1><p class="subtitle">Operations dashboard</p></div></div>
    @if ($errors->any())
        <div class="error">{{ $errors->first() }}</div>
    @endif
    <form method="post" action="{{ route('admin.authenticate') }}">
        @csrf
        <label for="email">Admin email</label>
        <input id="email" name="email" type="email" value="{{ old('email') }}" autocomplete="username" required autofocus>
        <label for="password">Password</label>
        <input id="password" name="password" type="password" autocomplete="current-password" required>
        <label class="remember"><input type="checkbox" name="remember" value="1"> Keep me signed in</label>
        <button type="submit">Sign in</button>
    </form>
    <p class="secure">Admin accounts only · Protected by an encrypted session</p>
</main>
</body>
</html>
