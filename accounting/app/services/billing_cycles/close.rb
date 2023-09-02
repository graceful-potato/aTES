# frozen_string_literal: true

class BillingCycles::Close < ApplicationService
  def call(billing_cycle)
    billing_cycle.closed!

    event = {
      event_id: SecureRandom.uuid,
      event_version: 1,
      event_time: DateTime.current,
      producer: "accounting",
      event_name: "BillingCycleClosed",
      data: {
        public_id: billing_cycle.public_id,
        account_id: billing_cycle.account_id
        status: billing_cycle.status,
      }
    }
    encoded_event = Base64.encode64(AVRO.encode(event, subject: "billing_cycle_stream.closed", version: 1))
    ProduceEventJob.perform_async("billing_cycle-stream", encoded_event)
  end
end
