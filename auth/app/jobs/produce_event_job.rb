# frozen_string_literal: true

require "sidekiq"

class ProduceEventJob
  include Sidekiq::Job

  def perform(topic, payload)
    binary_payload = Base64.decode64(payload)
    KafkaProducer.produce_sync(topic: topic, payload: binary_payload)
  end
end
