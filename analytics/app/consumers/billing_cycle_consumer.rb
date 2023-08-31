# frozen_string_literal: true

class BillingCycleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "BillingCycleCreated"
        account = Account.find_or_create_by(public_id: payload["data"]["account_id"])
        BillingCycle.find_or_create_by(public_id: payload["data"]["public_id"]).tap do |bc|
          bc.account = bc.account || account
          bc.starts_at = bc.starts_at || payload["data"]["starts_at"]
          bc.ends_at = bc.ends_at || payload["data"]["ends_at"]
          bc.status = bc.status || payload["data"]["status"]
          bc.created_at = bc.created_at || payload["data"]["created_at"]
          bc.save!
        end
      when "BillingCycleClosed"
        account = Account.find_or_create_by(public_id: payload["data"]["account_id"])
        billing_cycle = BillingCycle.find_or_create_by(public_id: payload["data"]["public_id"])
        billing_cycle.update!(status: payload["data"]["status"], account: account)
      end
    rescue StandardError => e
      # TODO: Notify developers about exception with bugsnag/sentry
      FailedEvent.create(topic: message.topic,
                         event_id: payload["event_id"],
                         event_version: payload["event_version"],
                         event_time: payload["event_time"],
                         producer: payload["producer"],
                         event_name: payload["event_name"],
                         error_message: e.full_message,
                         raw: payload)
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
