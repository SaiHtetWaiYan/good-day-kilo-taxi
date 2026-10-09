#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/good-day-kilo-taxi-api
ARCHIVE=/tmp/good-day-kilo-taxi-api.tgz
DB_NAME=goodday_kilo_taxi
DB_USER=goodday_kilo_taxi
DB_PASS="$(openssl rand -hex 24)"
NGINX_SITE=/etc/nginx/sites-available/good-day-kilo-taxi

install -d -m 0755 "$APP_DIR"
tar -xzf "$ARCHIVE" -C "$APP_DIR"
cd "$APP_DIR"

composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS'" >/dev/null
else
    sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS'" >/dev/null
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
fi

cat > .env <<EOF
APP_NAME="Good Day Kilo Taxi"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://taxi.saihtet.dev

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

LOG_CHANNEL=stack
LOG_STACK=single
LOG_LEVEL=warning

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

SESSION_DRIVER=database
SESSION_LIFETIME=120
CACHE_STORE=database
QUEUE_CONNECTION=database

ROUTING_URL=https://router.project-osrm.org
SERVICE_CITY=Yangon
CITY_SOUTH=16.55
CITY_NORTH=17.20
CITY_WEST=95.85
CITY_EAST=96.50
EOF

chmod 0640 .env
php artisan key:generate --force --no-interaction
php artisan migrate --seed --force --no-interaction
php artisan optimize

chown -R root:www-data "$APP_DIR"
chmod -R ug+rwX storage bootstrap/cache

if [ -f "$NGINX_SITE" ]; then
    cp "$NGINX_SITE" "$NGINX_SITE.bak.$(date +%Y%m%d%H%M%S)"
fi

cat > "$NGINX_SITE" <<'EOF'
server {
    server_name taxi.saihtet.dev;

    root /var/www/good-day-kilo-taxi-prototype;
    index index.html;

    location ^~ /api/ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/good-day-kilo-taxi-api/public/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param HTTPS on;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_read_timeout 75s;
    }

    location = /admin {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/good-day-kilo-taxi-api/public/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param HTTPS on;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location ^~ /admin/ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/good-day-kilo-taxi-api/public/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param HTTPS on;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/taxi.saihtet.dev/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/taxi.saihtet.dev/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if ($host = taxi.saihtet.dev) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    listen [::]:80;
    server_name taxi.saihtet.dev;
    return 404; # managed by Certbot
}
EOF

nginx -t
systemctl reload php8.4-fpm
systemctl reload nginx

echo "Good Day Kilo Taxi API deployment completed."
