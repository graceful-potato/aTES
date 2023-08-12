# frozen_string_literal: true

require "roda"
require_relative "db/connection"

class Auth < Roda
  plugin :json
  plugin :all_verbs
  plugin :halt
  plugin :rodauth, json: :only do
    enable :login, :jwt, :jwt_refresh, :create_account
    account_password_hash_column :password_hash
    jwt_algorithm "RS256"
    jwt_secret OpenSSL::PKey::RSA.new(ENV["PRIVATE_KEY"])
    hmac_secret ENV["SECRET_KEY"]
    allow_refresh_with_expired_jwt_access_token? true
    require_login_confirmation? false
    create_account_route "sign-up"
    login_route "sign-in"
    jwt_refresh_route "refresh-token"

    before_create_account do
      unless full_name = param_or_nil("full_name")
        throw_error_status(422, "full_name", "must be present")
      end
  
      account[:full_name] = full_name
    end
  end

  route do |r|
    r.rodauth
    rodauth.require_authentication

    r.root do
      { message: "hello" }
    end
  end
end
