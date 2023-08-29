# frozen_string_literal: true

class ProduceEventJob
  include Sidekiq::Job

  def perform(topic:, payload:)
    Karafka.producer.produce_sync(topic: topic, payload: payload)
  end
end
