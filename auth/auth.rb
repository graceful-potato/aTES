# frozen_string_literal: true

require "roda"
require "json"
require_relative "db/connection"
require_relative "lib/kafka_producer"
require_relative "app/models/account"

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

    jwt_session_hash do
      acc = Account[account[:id]]
      h = super()
      h.merge(public_id: acc.public_id)
    end

    before_create_account do
      unless full_name = param_or_nil("full_name")
        throw_error_status(422, "full_name", "must be present")
      end

      account[:full_name] = full_name
    end

    after_create_account do
      acc = Account[account[:id]]
      event = {
        event_name: "AccountCreated",
        data: {
          public_id: acc.public_id,
          email: acc.email,
          full_name: acc.full_name,
          role: acc.role
        }
      }

      KafkaProducer.produce_sync(topic: "accounts-stream", payload: event.to_json)
    end
  end

  route do |r|
    r.rodauth
    rodauth.require_authentication

    r.on "accounts" do
      if current_account.role != "admin"
        r.halt(403,
               { "Content-Type" => "application/json" },
               '{ "error": "Forbidden" }')
      end

      r.is do
        r.get do
          accounts = Account.all
          accounts.map do |acc|
            {
              id: acc.id,
              public_id: acc.public_id,
              email: acc.email,
              role: acc.role
            }
          end
        end
      end

      r.is Integer do |id|
        r.patch do
          unless acc = Account[id]
            r.halt(404,
                  { "Content-Type" => "application/json" },
                  "{ \"error\": \"Can't find account with id = #{id}\" }")
          end

          updated_params = r.params.slice("email", "full_name", "role")
          acc.update(updated_params)

          event = {
            event_name: "AccountUpdated",
            data: {
              public_id: acc.public_id,
              email: acc.email,
              full_name: acc.full_name,
              role: acc.role
            }
          }

          KafkaProducer.produce_sync(topic: "accounts-stream", payload: event.to_json)

          {
            id: acc.id,
            public_id: acc.public_id,
            email: acc.email,
            full_name: acc.full_name,
            role: acc.role
          }
        end

        r.delete do
          unless acc = Account[id]
            r.halt(404,
                  { "Content-Type" => "application/json" },
                  "{ \"error\": \"Can't find account with id = #{id}\" }")
          end

          event = {
            event_name: "AccountDeleted",
            data: {
              public_id: acc.public_id
            }
          }

          DB.transaction do
            DB[:account_jwt_refresh_keys].where(account_id: id).delete
            acc.destroy
          end

          KafkaProducer.produce_sync(topic: "accounts-stream", payload: event.to_json)

          { success: "Account with id = #{id} successfully deleted" }
        end
      end
    end
  end

  def current_account
    @_current_account ||= Account[rodauth.session_value]
  end
end
