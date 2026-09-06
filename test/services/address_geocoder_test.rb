require "test_helper"

class AddressGeocoderTest < ActiveSupport::TestCase
  NOMINATIM = %r{nominatim\.openstreetmap\.org}

  test "returns a location with zip and coordinates" do
    Geocoder::Lookup::Test.add_stub("350 5th Ave, New York, NY", [
      { "coordinates" => [ 40.748, -73.985 ], "postal_code" => "10118", "country_code" => "us",
        "address" => "Empire State Building, 350, 5th Avenue, New York, 10118, United States" }
    ])

    location = AddressGeocoder.locate("350 5th Ave, New York, NY")

    assert_equal "10118", location.zip
    assert_equal "us", location.country_code
    assert_equal 40.748, location.latitude
    assert_equal(-73.985, location.longitude)
    assert_match "Empire State Building", location.address
  end

  test "raises AddressNotFound when nothing matches" do
    Geocoder::Lookup::Test.add_stub("asdfqwerzxcv", [])

    error = assert_raises(AddressGeocoder::AddressNotFound) { AddressGeocoder.locate("asdfqwerzxcv") }
    assert_match "Couldn't find an address", error.message
  end

  test "raises AddressNotFound when the match has no zip code" do
    Geocoder::Lookup::Test.add_stub("California", [
      { "coordinates" => [ 36.7, -119.4 ], "postal_code" => nil, "country_code" => "us", "address" => "California, United States" }
    ])

    error = assert_raises(AddressGeocoder::AddressNotFound) { AddressGeocoder.locate("California") }
    assert_match "Couldn't determine a zip code", error.message
  end

  test "restricts the lookup to US addresses and caches the result" do
    with_lookup(:nominatim) do
      stub_request(:get, NOMINATIM).to_return(body: nominatim_response("10118").to_json)

      2.times { assert_equal "10118", AddressGeocoder.locate("350 5th Ave, New York, NY").zip }

      assert_requested :get, NOMINATIM, times: 1, query: hash_including("q" => "350 5th Ave, New York, NY", "countrycodes" => "us")
    end
  end

  test "treats ip-looking input as an address instead of an ip lookup" do
    with_lookup(:nominatim) do
      stub_request(:get, NOMINATIM).to_return(body: "[]")

      assert_raises(AddressGeocoder::AddressNotFound) { AddressGeocoder.locate("8.8.8.8") }
      assert_requested :get, NOMINATIM, query: hash_including("q" => "8.8.8.8")
    end
  end

  test "raises Unavailable when the lookup times out" do
    with_lookup(:nominatim) do
      stub_request(:get, NOMINATIM).to_timeout

      assert_raises(AddressGeocoder::Unavailable) { AddressGeocoder.locate("anything") }
    end
  end

  test "raises Unavailable when nominatim rate-limits the request" do
    with_lookup(:nominatim) do
      stub_request(:get, NOMINATIM).to_return(status: 429)

      assert_raises(AddressGeocoder::Unavailable) { AddressGeocoder.locate("anything") }
    end
  end

  private

  def with_lookup(lookup)
    Geocoder.configure(lookup: lookup)
    yield
  ensure
    Geocoder.configure(lookup: :test)
  end

  def nominatim_response(zip)
    [ { "lat" => "40.748", "lon" => "-73.985", "display_name" => "Empire State Building, New York, #{zip}, United States",
        "address" => { "postcode" => zip, "country_code" => "us" } } ]
  end
end
