# frozen_string_literal: true

require "bcrypt"
require_relative "connection"
require_relative "../app/models/account"

Account.create(
  email: "admin@example.com",
  status_id: 2, # verified
  role: "admin",
  full_name: "Admin",
  password_hash: BCrypt::Password.create("qwerty").to_s
)
