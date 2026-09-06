class ForecastFetcher
  TTL = 30.minutes

  def self.fetch(location)
    new(location).fetch
  end

  def initialize(location)
    @location = location
  end

  def fetch
    cache_miss = false
    forecast = Rails.cache.fetch(cache_key, expires_in: TTL) do
      cache_miss = true
      OpenMeteoClient.fetch(latitude: @location.latitude, longitude: @location.longitude)
    end

    ForecastResult.new(forecast:, from_cache: !cache_miss, expires_at: forecast.fetched_at + TTL)
  end

  private

  def cache_key
    [ "forecast", "v1", @location.country_code, @location.zip ]
  end
end
