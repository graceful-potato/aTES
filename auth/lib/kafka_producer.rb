# frozen_string_literal: true

require "waterdrop"

KafkaProducer = WaterDrop::Producer.new

KafkaProducer.setup do |config|
  config.kafka = { "bootstrap.servers": "localhost:9092" }
end
