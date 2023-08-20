# frozen_string_literal: true

class AccountConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "AccountCreated"
        Account.find_or_create_by(public_id: payload["data"]["public_id"]).tap do |acc|
          acc.email = payload["data"]["email"] unless acc.email
          acc.full_name = payload["data"]["full_name"] unless acc.full_name
          acc.role = payload["data"]["role"] unless acc.role
          acc.save!
        end
      when "AccountUpdated"
        account = Account.find_or_create_by(public_id: payload["data"]["public_id"])
        account.update(email: payload["data"]["email"],
                       full_name: payload["data"]["full_name"],
                       role: payload["data"]["role"])
      when "AccountDeleted"
        account = Account.find_by(public_id: payload["data"]["public_id"])
        account.destroy if account
      end
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
