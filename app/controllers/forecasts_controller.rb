class ForecastsController < ApplicationController
  before_action :set_address
  rate_limit to: 30, within: 1.minute, with: :rate_limited

  rescue_from AddressGeocoder::AddressNotFound, with: :address_not_found
  rescue_from AddressGeocoder::Unavailable, OpenMeteoClient::Unavailable, with: :service_unavailable

  def show
    return if @address.blank?

    @location = AddressGeocoder.locate(@address)
    @result = ForecastFetcher.fetch(@location)
  end

  private

  def set_address
    @address = params[:address].to_s.strip
  end

  def address_not_found(error)
    @error = error.message
    render :show, status: :unprocessable_content
  end

  def service_unavailable(error)
    Rails.error.report(error, handled: true)
    response.headers["Retry-After"] = "30"
    @error = t("forecasts.errors.service_unavailable")
    render :show, status: :service_unavailable
  end

  def rate_limited
    response.headers["Retry-After"] = "60"
    @error = t("forecasts.errors.rate_limited")
    render :show, status: :too_many_requests
  end
end
