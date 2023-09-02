require "avro_turf/messaging"

avro = AvroTurf::Messaging.new(
  registry_url: "http://nginx:8081/",
  user: ENV["SCHEMA_REGISTRY_USER"],
  password: ENV["SCHEMA_REGISTRY_PASSWORD"]
)

path = File.expand_path("../schemas", __FILE__)
pattern = [path, "**", "*.avsc"].join("/")

Dir.glob(pattern) do |schema_path|
  # Remove the path prefix.
  schema_path.sub!(/^\/?#{path}\//, "")

  # Replace `/` with `.` and chop off the file extension.
  schema_name = File.basename(schema_path.tr("/", "."), ".avsc")

  avro.register_schema(schema_name: schema_name)
end
