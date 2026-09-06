class AddressGeocoder
  class Error < StandardError; end
  class AddressNotFound < Error; end
  class Unavailable < Error; end

  COUNTRY_CODE = "us"
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Geocoder::Error ].freeze

  def self.locate(address)
    new(address).locate
  end

  def initialize(address)
    @address = address
  end

  def locate
    result = search.first
    raise AddressNotFound, "Couldn't find an address matching \"#{@address}\"" if result.nil?
    raise AddressNotFound, "Couldn't determine a zip code for \"#{@address}\"" if result.postal_code.blank?

    Location.new(
      zip: result.postal_code,
      country_code: result.country_code,
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address
    )
  end

  private

  def search
    Geocoder.search(@address, street_address: true, params: { countrycodes: COUNTRY_CODE })
  rescue *NETWORK_ERRORS => e
    raise Unavailable, "Address lookup failed (#{e.class})"
  end
end
