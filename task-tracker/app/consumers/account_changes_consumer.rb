# frozen_string_literal: true

# Example consumer that prints messages payloads
class AccountChangesConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "AccountCreated"
        Account.create(email: payload["data"]["email"],
                       full_name: payload["data"]["full_name"],
                       public_id: payload["data"]["public_id"],
                       role: payload["data"]["role"])
      when "AccountUpdated"
        account = Account.find_by(public_id: payload["data"]["public_id"])
        account.update(email: payload["data"]["email"],
                       full_name: payload["data"]["full_name"],
                       role: payload["data"]["role"])
      when "AccountDeleted"
        account = Account.find_by(public_id: payload["data"]["public_id"])
        account.destroy
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
