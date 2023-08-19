# frozen_string_literal: true

require "avro_turf/messaging"

AVRO = AvroTurf::Messaging.new(schemas_path: File.expand_path("../../app/schemas", __FILE__),
                               registry_url: "http://schema-registry:8081/")

