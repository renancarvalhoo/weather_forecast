module ForecastsHelper
  WEATHER_ICONS = {
    0 => "☀️", 1 => "🌤️", 2 => "⛅", 3 => "☁️",
    45 => "🌫️", 48 => "🌫️",
    51 => "🌦️", 53 => "🌦️", 55 => "🌧️", 56 => "🌧️", 57 => "🌧️",
    61 => "🌧️", 63 => "🌧️", 65 => "🌧️", 66 => "🌧️", 67 => "🌧️",
    71 => "🌨️", 73 => "🌨️", 75 => "❄️", 77 => "🌨️",
    80 => "🌦️", 81 => "🌧️", 82 => "⛈️", 85 => "🌨️", 86 => "❄️",
    95 => "⛈️", 96 => "⛈️", 99 => "⛈️"
  }.freeze

  def weather_description(code)
    t("weather.#{code}", default: :"weather.unknown")
  end

  def weather_icon(code)
    WEATHER_ICONS.fetch(code, "🌡️")
  end

  def fahrenheit(celsius)
    (celsius * 9.0 / 5 + 32).round
  end

  def temperature(celsius)
    "#{fahrenheit(celsius)}°F / #{celsius.round}°C"
  end
end
