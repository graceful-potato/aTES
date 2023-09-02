# frozen_string_literal: true

require "bcrypt"
require "json"
require_relative "connection"
require_relative "../app/models/account"
require_relative "../lib/avro"
require_relative "../lib/kafka_producer"

acc = Account.create(
  email: "admin@example.com",
  status_id: 2, # verified
  role: "admin",
  full_name: "Admin",
  password_hash: BCrypt::Password.create("qwerty").to_s
)

event = {
  event_id: SecureRandom.uuid,
  event_version: 1,
  event_time: Time.now.utc.to_datetime,
  producer: "auth",
  event_name: "AccountCreated",
  data: {
    public_id: acc.public_id,
    email: acc.email,
    full_name: acc.full_name,
    role: acc.role
  }
}

encoded_event = AVRO.encode(event, subject: "accounts_stream.created", version: 1)
KafkaProducer.produce_sync(topic: "accounts-stream", payload: encoded_event)
