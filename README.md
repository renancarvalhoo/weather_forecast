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
