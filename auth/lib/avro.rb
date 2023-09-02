# frozen_string_literal: true

require "avro_turf/messaging"

AVRO = AvroTurf::Messaging.new(registry_url: "http://nginx:8081/")
