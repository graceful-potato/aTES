# frozen_string_literal: true

class BillingCycles::FetchOrCreate < ApplicationService
  def call(account, start_time, end_time)
    billing_cycle = account.billing_cycles.find_by(starts_at: start_time, ends_at: end_time)

    if billing_cycle.nil?
      billing_cycle = account.billing_cycles.create!(starts_at: start_time, ends_at: end_time).reload

      event = {
        event_id: SecureRandom.uuid,
        event_version: 1,
        event_time: DateTime.current,
        producer: "accounting",
        event_name: "BillingCycleCreated",
        data: {
          public_id: billing_cycle.public_id,
          account_id: billing_cycle.account_id,
          starts_at: billing_cycle.starts_at,
          ends_at: billing_cycle.ends_at,
          status: billing_cycle.status,
          created_at: billing_cycle.created_at
        }
      }
      encoded_event = Base64.encode64(AVRO.encode(event, subject: "billing_cycle_stream.created", version: 1))
      ProduceEventJob.perform_async("billing_cycle-stream", encoded_event)

      billing_cycle
    else
      billing_cycle
    end
  end
end
