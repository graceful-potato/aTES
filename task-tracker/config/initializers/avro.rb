# frozen_string_literal: true

require "avro_turf/messaging"

AVRO = AvroTurf::Messaging.new(schemas_path: Rails.root.join("app", "schemas"),
                               registry_url: "http://schema-registry:8081/")
