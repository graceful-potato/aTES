# frozen_string_literal: true

require "json_web_token"

class ApplicationController < ActionController::API
  rescue_from Avro::IO::AvroTypeError do |exception|
    render json: { error: "Schema validation error" }, status: 500
  end

  def authenticate_account!
    render json: { error: "Not Authorized" }, status: 401 unless current_account
  end

  def current_account
    @_current_account ||= payload && payload[:public_id] && Account.find_by(public_id: payload[:public_id])
  end

  def account_signed_in?
    !!current_account
  end

  private

  def token
    @_token ||= request.headers["Authorization"]
  end

  def payload
    @_payload ||= JsonWebToken.decode(token)
  end
end
