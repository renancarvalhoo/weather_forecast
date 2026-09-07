# Weather forecast

Type a US address and you get the current temperature and the next 7 days. The app caches results by zip code for 30 minutes and tells you when the result you see came from that cache.

There are no API keys. Geocoding goes through Nominatim (OpenStreetMap) and the weather data comes from Open-Meteo.

## Running it

You need Ruby 3.3.6. Nothing else, no Node or Redis.

```sh
bin/setup
```

That installs the gems, creates the SQLite databases, builds the CSS and starts the server. Open http://localhost:3000.

To start it again later:

```sh
bin/dev
```

Tests:

```sh
bin/rails test
```

They don't touch the network.

`bin/rails s` also works, but the page comes up unstyled until you run `bin/rails tailwindcss:build`. And if you skip `bin/setup`, the first search fails with "Could not find table 'solid_cache_entries'"; `bin/rails db:prepare` creates it.

## How it works

Everything is one request: `GET /forecast?address=...`

The address goes to Nominatim, which returns a zip and coordinates. I look the zip up in `Rails.cache`. If it's not there, I ask Open-Meteo for the forecast at those coordinates and keep it for 30 minutes. The badge on the page shows whether it was a hit, when it was fetched and when it expires.

Three classes do the work: `AddressGeocoder`, `ForecastFetcher` and `OpenMeteoClient`. There is no database of my own, only the Solid Cache table.

## Why I did it this way

I was going to use OpenWeatherMap, then realized the reviewer would have to create an account before the app even runs. Nominatim and Open-Meteo need no key.

Caching by zip is what the brief asks for, and it's the only key that works in practice. People type the same address ten different ways, and coordinates change slightly between lookups. The side effect is that the first address looked up in a zip pins the forecast for that zip for 30 minutes.

Rails uses a memory store in development by default, which disappears on every restart and makes the cache badge annoying to demo. Solid Cache is a SQLite table, so it survives restarts. You don't need `rails dev:cache` for this; that flag only affects fragment caching.

The TTL is `expires_in: 30.minutes` on `Rails.cache.fetch`, and the `v1` in the key lets me change the cached object later without wiping the whole store. `Rails.cache.fetch` doesn't say whether it hit. I set a flag inside the block, because the block only runs on a miss.

The cache holds Celsius, exactly what the API returns, and the view converts to Fahrenheit, so changing how temperatures are shown never invalidates a cache entry.

The search is a GET because it's a lookup and the URL should be shareable. The form and the result live in one Turbo Frame, so Turbo swaps only that frame; without JavaScript it's a normal page load. The rate limit is 30 requests a minute per IP, using the Rails `rate_limit` line, because Nominatim blocks apps that exceed one request per second.

## Things that bit me

- "90210" came back as a village in Ukraine, because Nominatim searches the whole planet. I restricted lookups to the US.
- The geocoder gem swallows timeouts and returns an empty array, so "Nominatim is down" looked the same as "address not found". `always_raise: :all` fixed it. The gem also sends anything that looks like an IP to a different service; `street_address: true` stops that.
- After I turned on CSP, Turbo's progress bar stopped working. It injects an inline `<style>`, so `style-src` needs a nonce as well.
- Turbo doesn't update the URL on a 422. I first read that as a bug. In practice it means a bad search doesn't end up in the browser history.

## Limitations

- US only.
- Nominatim sometimes returns ZIP+4, which would become a separate cache entry.
- If Open-Meteo is down and the cache has expired, you get a 503 rather than old data.
- The rate limit is per IP, so anyone behind a proxy can get around it. It exists to be polite to Nominatim.

## What I'd do next

Show stale data with a warning when Open-Meteo is down. Add a °C/°F toggle. Write a system test for the frame swap, which I have only checked by hand in the browser so far.
