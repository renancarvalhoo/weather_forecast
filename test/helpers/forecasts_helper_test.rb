require "test_helper"

class ForecastsHelperTest < ActionView::TestCase
  test "converts celsius to fahrenheit" do
    assert_equal 32, fahrenheit(0)
    assert_equal 69, fahrenheit(20.7)
    assert_equal "69°F / 21°C", temperature(20.7)
  end

  test "describes wmo weather codes" do
    assert_equal "Partly cloudy", weather_description(2)
    assert_equal "⛈️", weather_icon(95)
    assert_equal "Unknown conditions", weather_description(42)
  end
end
