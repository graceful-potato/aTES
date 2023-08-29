# frozen_string_literal: true

class AuditLogConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = AVRO.decode(message.raw_payload)

      puts "-" * 80
      puts payload
      puts "-" * 80

      case payload["event_name"]
      when "AuditLogCreated"
        AuditLog.create!(public_id: payload["data"]["public_id"],
                         account_id: payload["data"]["account_id"],
                         task_id: payload["data"]["task_id"],
                         amount: payload["data"]["amount"],
                         event_type: payload["data"]["event_type"],
                         created_at: payload["data"]["created_at"])
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
