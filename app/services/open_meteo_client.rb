require "net/http"

class OpenMeteoClient
  class Error < StandardError; end
  class Unavailable < Error; end

  ENDPOINT = URI("https://api.open-meteo.com/v1/forecast").freeze
  TIMEOUT = 5
  QUERY = {
    current: "temperature_2m,weather_code",
    daily: "temperature_2m_max,temperature_2m_min,weather_code",
    temperature_unit: "celsius",
    timezone: "auto",
    forecast_days: 7
  }.freeze
  NETWORK_ERRORS = [
    Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse
  ].freeze

  def self.fetch(latitude:, longitude:)
    new.fetch(latitude:, longitude:)
  end

  def fetch(latitude:, longitude:)
    build_forecast(request(latitude:, longitude:))
  end

  private

  def request(latitude:, longitude:)
    uri = ENDPOINT.dup
    uri.query = URI.encode_www_form(QUERY.merge(latitude:, longitude:))

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
    raise Unavailable, "Open-Meteo responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body, symbolize_names: true)
  rescue *NETWORK_ERRORS, JSON::ParserError => e
    raise Unavailable, "Open-Meteo request failed (#{e.class})"
  end

  def build_forecast(data)
    data => { timezone:, current: { temperature_2m:, weather_code: }, daily: }

    Forecast.new(
      current_temperature: temperature_2m,
      current_weather_code: weather_code,
      timezone:,
      daily: build_days(daily),
      fetched_at: Time.current
    )
  rescue NoMatchingPatternError
    raise Unavailable, "Open-Meteo returned an unexpected payload"
  end

  def build_days(daily)
    daily => { time:, temperature_2m_max:, temperature_2m_min:, weather_code: }

    time.zip(temperature_2m_max, temperature_2m_min, weather_code).map do |date, high, low, code|
      Forecast::Day.new(date: Date.iso8601(date), high:, low:, weather_code: code)
    end
  end
end
