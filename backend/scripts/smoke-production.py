#!/usr/bin/env python3
import json
import time
import urllib.error
import urllib.request


BASE_URL = "https://taxi.saihtet.dev/api"
RUN_ID = str(int(time.time()))


def request(method, path, payload=None, token=None):
    body = json.dumps(payload).encode() if payload is not None else None
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE_URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        detail = raw.decode("utf-8", "replace")
        raise AssertionError(f"{method} {path} returned {error.code}: {detail}") from error


def register(role, name, plate=None):
    payload = {
        "name": name,
        "email": f"codex-smoke-{RUN_ID}-{role}@example.test",
        "phone": f"09{RUN_ID[-8:]}{'1' if role == 'passenger' else '2'}",
        "password": "SmokeTest123!",
        "role": role,
    }
    if plate:
        payload["vehicle_plate"] = plate
    status, data = request("POST", "/register", payload)
    assert status == 201
    return data["token"]


passenger_token = register("passenger", "Smoke Passenger")
driver_token = register("driver", "Smoke Driver", "SMOKE-01")

status, driver = request(
    "PUT",
    "/driver/location",
    {"latitude": 16.7750, "longitude": 96.1585, "is_available": True},
    driver_token,
)
assert status == 200 and driver["is_available"] is True
print("1/7 driver online")

status, quote = request(
    "POST",
    "/quotes",
    {"pickup": {"place_id": "sule"}, "destination": {"place_id": "shwedagon"}},
    passenger_token,
)
assert status == 201 and quote["fare_minor"] > 2000 and quote["distance_meters"] > 0
print(f"2/7 quote created: {quote['distance_meters']} m, {quote['fare_minor']} MMK")

status, booking = request("POST", "/bookings", {"quote_id": quote["quote_id"]}, passenger_token)
assert status == 201 and booking["status"] == "searching"
booking_id = booking["id"]
print(f"3/7 booking {booking_id} searching")

status, offers = request("GET", "/driver/offers", token=driver_token)
assert status == 200 and any(item["id"] == booking_id for item in offers["offers"])
print("4/7 nearby driver received offer")

status, accepted = request("POST", f"/bookings/{booking_id}/accept", {}, driver_token)
assert status == 200 and accepted["status"] == "accepted" and accepted["driver"]["vehicle_plate"] == "SMOKE-01"
assert accepted["driver"]["phone"] and accepted["passenger"]["phone"]
print("5/7 driver accepted; passenger-visible driver attached")

status, passenger_view = request("GET", f"/bookings/{booking_id}", token=passenger_token)
assert status == 200 and passenger_view["status"] == "accepted"

status, started = request("POST", f"/bookings/{booking_id}/start", {}, driver_token)
assert status == 200 and started["status"] == "started"
print("6/7 ride started")

status, completed = request("POST", f"/bookings/{booking_id}/complete", {}, driver_token)
assert status == 200 and completed["status"] == "completed"
print("7/7 ride completed")
print(f"SMOKE_RUN_ID={RUN_ID}")
