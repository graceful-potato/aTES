# frozen_string_literal: true

require "waterdrop"

KafkaProducer = WaterDrop::Producer.new

KafkaProducer.setup do |config|
  config.kafka = {
    "bootstrap.servers": "kafka:9092",
    "client.id": "auth_service"
  }
end
