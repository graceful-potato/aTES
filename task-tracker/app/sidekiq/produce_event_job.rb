# frozen_string_literal: true

class ProduceEventJob
  include Sidekiq::Job

  def perform(topic, payload)
    binary_payload = Base64.decode64(payload)
    Karafka.producer.produce_sync(topic: topic, payload: binary_payload)
  end
end
