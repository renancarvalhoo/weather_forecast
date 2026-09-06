ForecastResult = Data.define(:forecast, :from_cache, :expires_at) do
  def from_cache? = from_cache
end
