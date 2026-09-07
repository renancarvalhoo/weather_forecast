require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  OPEN_METEO = %r{api\.open-meteo\.com/v1/forecast}

  setup do
    stub_geocoding("350 5th Ave, New York, NY", zip: "10118", address: "Empire State Building, New York, 10118, United States")
    stub_geocoding("20 W 34th St, New York, NY", zip: "10118", address: "20 West 34th Street, New York, 10118, United States")
    stub_request(:get, OPEN_METEO).to_return(body: file_fixture("open_meteo_forecast.json").read)
    travel_to Time.zone.local(2026, 9, 6, 12)
  end

  test "renders the search form" do
    get root_path

    assert_response :ok
    assert_select "turbo-frame#forecast form[action='/forecast'][method='get'] input[name='address']"
    assert_select "turbo-frame#forecast section", false
  end

  test "renders the form without any lookups for a blank address" do
    get forecast_path(address: "   ")

    assert_response :ok
    assert_select "turbo-frame#forecast section", false
    assert_not_requested :get, OPEN_METEO
  end

  test "shows the forecast for an address" do
    get forecast_path(address: "350 5th Ave, New York, NY")

    assert_response :ok
    assert_select "p", text: "Empire State Building, New York, 10118, United States"
    assert_select "p", text: /69°F/
    assert_select "p", text: /Partly cloudy · High 74°F \/ 24°C · Low 63°F \/ 17°C/
    assert_select "ol li", count: 7
    assert_select "span", text: /Fresh from Open-Meteo · cached for 10118 for the next 30 minutes/
  end

  test "marks a later request for the same zip as cached" do
    get forecast_path(address: "350 5th Ave, New York, NY")
    travel 4.minutes
    get forecast_path(address: "20 W 34th St, New York, NY")

    assert_response :ok
    assert_select "p", text: "20 West 34th Street, New York, 10118, United States"
    assert_select "span", text: /Cached for 10118 · fetched 4 minutes ago · expires in 26 minutes/
    assert_requested :get, OPEN_METEO, times: 1
  end

  test "explains when the address cannot be found" do
    Geocoder::Lookup::Test.add_stub("nowhere", [])

    get forecast_path(address: "nowhere")

    assert_response :unprocessable_content
    assert_select "turbo-frame#forecast [role=alert]", text: %(Couldn't find an address matching "nowhere")
    assert_select "input[name='address'][value='nowhere']"
  end

  test "explains when the weather service is unavailable" do
    stub_request(:get, OPEN_METEO).to_timeout

    get forecast_path(address: "350 5th Ave, New York, NY")

    assert_response :service_unavailable
    assert_equal "30", response.headers["Retry-After"]
    assert_select "[role=alert]", text: /weather service is unavailable/
  end

  test "explains when the address lookup is unavailable" do
    Geocoder.configure(lookup: :nominatim)
    stub_request(:get, /nominatim\.openstreetmap\.org/).to_timeout

    get forecast_path(address: "350 5th Ave, New York, NY")

    assert_response :service_unavailable
    assert_select "[role=alert]", text: /weather service is unavailable/
  ensure
    Geocoder.configure(lookup: :test)
  end

  test "rate limits repeated requests from the same client" do
    30.times { get forecast_path(address: "350 5th Ave, New York, NY") }
    assert_response :ok

    get forecast_path(address: "350 5th Ave, New York, NY")

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_select "[role=alert]", text: /Too many requests/
  end

  private

  def stub_geocoding(query, zip:, address:)
    Geocoder::Lookup::Test.add_stub(query, [
      { "coordinates" => [ 40.748, -73.985 ], "postal_code" => zip, "country_code" => "us", "address" => address }
    ])
  end
end
