Forecast = Data.define(:current_temperature, :current_weather_code, :timezone, :daily, :fetched_at) do
  def today
    daily.first
  end
end

Forecast::Day = Data.define(:date, :high, :low, :weather_code)
