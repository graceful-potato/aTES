# frozen_string_literal: true

require "sidekiq"

class ProduceEventJob
  include Sidekiq::Job

  def perform(topic:, payload:)
    KafkaProducer.produce_sync(topic: topic, payload: payload)
  end
end
