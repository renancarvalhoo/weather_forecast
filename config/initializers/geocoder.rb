Geocoder.configure(
  lookup: :nominatim,
  timeout: 5,
  always_raise: :all,
  http_headers: { "User-Agent" => "weather_forecast (github.com/renancarvalho)" },
  cache: Rails.cache,
  cache_options: { expiration: 1.day }
)
