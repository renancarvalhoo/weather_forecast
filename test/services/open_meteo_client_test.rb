require "test_helper"

class OpenMeteoClientTest < ActiveSupport::TestCase
  ENDPOINT = %r{api\.open-meteo\.com/v1/forecast}

  test "builds a forecast from the api response" do
    stub_request(:get, ENDPOINT).to_return(body: file_fixture("open_meteo_forecast.json").read)

    travel_to Time.zone.local(2026, 9, 6, 12)

    forecast = OpenMeteoClient.fetch(latitude: 40.748, longitude: -73.985)

    assert_equal 20.7, forecast.current_temperature
    assert_equal 2, forecast.current_weather_code
    assert_equal "America/New_York", forecast.timezone
    assert_equal Time.zone.local(2026, 9, 6, 12), forecast.fetched_at
    assert_equal 7, forecast.daily.size
    assert_equal Forecast::Day.new(date: Date.new(2026, 9, 6), high: 23.5, low: 17.0, weather_code: 3), forecast.today
    assert_equal 55, forecast.daily[5].weather_code
  end

  test "requests current and daily data for the given coordinates" do
    stub_request(:get, ENDPOINT).to_return(body: file_fixture("open_meteo_forecast.json").read)

    OpenMeteoClient.fetch(latitude: 40.748, longitude: -73.985)

    assert_requested :get, ENDPOINT, query: hash_including(
      "latitude" => "40.748", "longitude" => "-73.985",
      "current" => "temperature_2m,weather_code",
      "daily" => "temperature_2m_max,temperature_2m_min,weather_code",
      "temperature_unit" => "celsius", "timezone" => "auto", "forecast_days" => "7"
    )
  end

  test "raises Unavailable on a non-success response" do
    stub_request(:get, ENDPOINT).to_return(status: 500, body: "boom")

    error = assert_raises(OpenMeteoClient::Unavailable) { OpenMeteoClient.fetch(latitude: 1, longitude: 2) }
    assert_match "500", error.message
  end

  test "raises Unavailable on an unexpected payload" do
    stub_request(:get, ENDPOINT).to_return(body: "{}")

    error = assert_raises(OpenMeteoClient::Unavailable) { OpenMeteoClient.fetch(latitude: 1, longitude: 2) }
    assert_match "unexpected payload", error.message
  end

  test "raises Unavailable on timeout" do
    stub_request(:get, ENDPOINT).to_timeout

    assert_raises(OpenMeteoClient::Unavailable) { OpenMeteoClient.fetch(latitude: 1, longitude: 2) }
  end
end
