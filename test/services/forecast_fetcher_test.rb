require "test_helper"

class ForecastFetcherTest < ActiveSupport::TestCase
  ENDPOINT = %r{api\.open-meteo\.com/v1/forecast}

  setup do
    stub_request(:get, ENDPOINT).to_return(body: file_fixture("open_meteo_forecast.json").read)
    travel_to Time.zone.local(2026, 9, 6, 12)
  end

  test "fetches from the api on a cache miss" do
    result = ForecastFetcher.fetch(new_york)

    assert_not result.from_cache?
    assert_equal 20.7, result.forecast.current_temperature
    assert_equal Time.zone.local(2026, 9, 6, 12, 30), result.expires_at
    assert_requested :get, ENDPOINT, times: 1
  end

  test "serves the cached forecast for any address in the same zip" do
    first = ForecastFetcher.fetch(new_york)
    travel 10.minutes
    second = ForecastFetcher.fetch(new_york.with(latitude: 40.75, longitude: -73.99, address: "20 W 34th St, New York, NY 10118"))

    assert second.from_cache?
    assert_equal first.forecast, second.forecast
    assert_equal first.expires_at, second.expires_at
    assert_requested :get, ENDPOINT, times: 1
  end

  test "expires exactly 30 minutes after the first fetch" do
    ForecastFetcher.fetch(new_york)

    travel 30.minutes - 1.second
    assert ForecastFetcher.fetch(new_york).from_cache?

    travel 1.second
    result = ForecastFetcher.fetch(new_york)
    assert_not result.from_cache?
    assert_equal Time.zone.local(2026, 9, 6, 13), result.expires_at
    assert_requested :get, ENDPOINT, times: 2
  end

  test "keeps a separate entry per country and zip" do
    ForecastFetcher.fetch(new_york)
    ForecastFetcher.fetch(beverly_hills)
    ForecastFetcher.fetch(new_york.with(country_code: "ca"))

    assert_requested :get, ENDPOINT, times: 3
  end

  test "does not cache a failed fetch" do
    stub_request(:get, ENDPOINT).to_return(status: 500)
    assert_raises(OpenMeteoClient::Unavailable) { ForecastFetcher.fetch(new_york) }

    stub_request(:get, ENDPOINT).to_return(body: file_fixture("open_meteo_forecast.json").read)
    assert_not ForecastFetcher.fetch(new_york).from_cache?
  end

  private

  def new_york
    Location.new(zip: "10118", country_code: "us", latitude: 40.748, longitude: -73.985, address: "350 5th Ave, New York, NY 10118")
  end

  def beverly_hills
    Location.new(zip: "90210", country_code: "us", latitude: 34.094, longitude: -118.411, address: "Beverly Hills, CA 90210")
  end
end
